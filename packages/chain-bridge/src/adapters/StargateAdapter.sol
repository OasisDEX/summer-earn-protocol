// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICrossChainAssetReceiver} from "../interfaces/ICrossChainAssetReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

// Import CrossChain Ark interface for proper detection
import {ICrossChainArk} from "../interfaces/ICrossChainArk.sol";

// Stargate V2 interfaces - based on LayerZero V2 OFT standard
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt, OFTLimit, OFTFeeDetail} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
// Add LayerZero composability imports
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

/**
 * @title IStargate interface for V2
 * @notice Based on LayerZero V2 OFT standard with Stargate extensions
 */
interface IStargate {
    enum StargateType {
        Pool,
        OFT
    }

    struct Ticket {
        uint56 ticketId;
        bytes passenger;
    }

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt,
            Ticket memory ticket
        );

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory msgFee);

    function quoteOFT(
        SendParam calldata _sendParam
    )
        external
        view
        returns (
            OFTLimit memory limit,
            OFTFeeDetail[] memory oftFeeDetails,
            OFTReceipt memory oftReceipt
        );

    function stargateType() external pure returns (StargateType);

    function token() external view returns (address);
}

/**
 * @title OftCmdHelper
 * @notice Helper for creating OFT commands for taxi/bus modes
 */
library OftCmdHelper {
    function taxi() internal pure returns (bytes memory) {
        return "";
    }

    function bus() internal pure returns (bytes memory) {
        return new bytes(1);
    }

    function drive(
        bytes memory _passengers
    ) internal pure returns (bytes memory) {
        return _passengers;
    }
}

/**
 * @title StargateAdapter
 * @notice Adapter for Stargate V2 Protocol - all V2 contracts are OFT-enabled
 * @dev Implements IBridgeAdapter interface and connects to Stargate V2 for efficient cross-chain transfers
 */
contract StargateAdapter is Ownable, IBridgeAdapter, ILayerZeroComposer {
    using SafeERC20 for IERC20;
    using AddressCast for address;
    using OptionsBuilder for bytes;

    /// @notice Error for unsupported asset
    error UnsupportedAsset();

    /// @notice Error for insufficient balance
    error InsufficientBalance();

    /// @notice Transfer parameters struct to avoid stack too deep
    struct TransferParams {
        address stargateContract;
        uint16 destinationChainId;
        address asset;
        address recipient;
        uint256 amount;
        address originator;
        address keeper;
        bytes32 operationId;
    }

    /// @notice Maximum gas limit for compose execution
    uint256 public constant MAX_COMPOSE_GAS = 1000000;

    /// @notice Information about failed compose operations for recovery
    struct FailedCompose {
        address asset;
        uint256 amount;
        address intendedRecipient;
        bytes32 operationId;
        address originator;
        uint16 sourceChainId;
        uint256 timestamp;
        bool isDeposit; // true for deposits to FleetProxy, false for withdrawals to CrossChainArk
    }

    /// @notice Mapping of operation IDs to failed compose details
    mapping(bytes32 => FailedCompose) public failedComposes;

    /// @notice Array of failed operation IDs for easier iteration
    bytes32[] public failedOperationIds;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeRouter that manages this adapter
    address public bridgeRouter;

    /// @notice LayerZero endpoint for compose functionality
    address public immutable lzEndpoint;

    /// @notice Mapping of supported chains to their LayerZero Endpoint IDs
    mapping(uint16 chainId => uint32 endpointId) public chainToEndpointId;

    /// @notice Mapping of assets to their Stargate contracts on THIS chain only
    mapping(address asset => address stargateContract)
        public assetToStargateContract;

    /// @notice Mapping of destination chains to their StargateAdapter addresses
    mapping(uint16 chainId => address adapterAddress) public chainToAdapter;

    /// @notice List of supported chains
    uint16[] public supportedChains;

    /// @notice Default transport mode (true = taxi, false = bus)
    /// @dev Taxi mode is required for composability - bus mode does not support compose
    bool public defaultUseTaxi = true;

    /// @notice Gas limit for compose execution on destination
    uint256 public composeGasLimit = 400000;

    /// @notice Minimum gas limit for compose execution
    uint256 public constant MIN_COMPOSE_GAS = 200000;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a chain support is added
    event ChainSupported(uint16 chainId, uint32 endpointId);

    /// @notice Emitted when an asset support is added
    event AssetSupported(
        uint16 chainId,
        address asset,
        address stargateContract
    );

    /// @notice Emitted when default transport mode is changed
    event DefaultTransportModeChanged(bool useTaxi);

    /// @notice Emitted when compose gas limit is updated
    event ComposeGasLimitUpdated(uint256 newGasLimit);

    /// @notice Emitted when composed assets are handled
    event ComposedAssetHandled(
        bytes32 indexed operationId,
        address indexed fleetProxy,
        address indexed asset,
        uint256 amount,
        uint16 sourceChainId
    );

    /// @notice Emitted when compose call fails
    event ComposeCallFailed(
        bytes32 indexed operationId,
        address indexed fleetProxy,
        bytes reason
    );

    /// @notice Emitted when stuck tokens are recovered
    event TokensRecovered(
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );

    /// @notice Emitted when a compose operation fails and assets are held for recovery
    event ComposeFailedAssetsHeld(
        bytes32 indexed operationId,
        address indexed asset,
        uint256 amount,
        address intendedRecipient,
        bool isDeposit,
        string reason
    );

    /// @notice Emitted when a failed compose operation is recovered
    event FailedComposeRecovered(
        bytes32 indexed operationId,
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the StargateAdapter
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _owner Address of the contract owner
     * @param _lzEndpoint LayerZero endpoint for compose functionality
     */
    constructor(
        address _bridgeRouter,
        address _owner,
        address _lzEndpoint
    ) Ownable(_owner) {
        if (_bridgeRouter == address(0)) revert InvalidParams();
        if (_lzEndpoint == address(0)) revert InvalidParams();

        bridgeRouter = _bridgeRouter;
        lzEndpoint = _lzEndpoint;
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the default transport mode
     * @param _useTaxi True for taxi mode (immediate), false for bus mode (batched)
     */
    function setDefaultTransportMode(bool _useTaxi) external onlyOwner {
        defaultUseTaxi = _useTaxi;
        emit DefaultTransportModeChanged(_useTaxi);
    }

    /**
     * @notice Sets the gas limit for compose execution
     * @param _composeGasLimit New gas limit for compose execution
     */
    function setComposeGasLimit(uint256 _composeGasLimit) external onlyOwner {
        if (
            _composeGasLimit < MIN_COMPOSE_GAS ||
            _composeGasLimit > MAX_COMPOSE_GAS
        ) {
            revert InvalidParams();
        }
        composeGasLimit = _composeGasLimit;
        emit ComposeGasLimitUpdated(_composeGasLimit);
    }

    /**
     * @notice Adds support for a new chain
     * @param chainId Chain ID in our system
     * @param endpointId Corresponding LayerZero Endpoint ID
     * @param adapterAddress Address of the StargateAdapter for this chain
     */
    function addSupportedChain(
        uint16 chainId,
        uint32 endpointId,
        address adapterAddress
    ) external onlyOwner {
        if (chainToEndpointId[chainId] != 0) revert InvalidParams();

        chainToEndpointId[chainId] = endpointId;
        chainToAdapter[chainId] = adapterAddress;
        supportedChains.push(chainId);

        emit ChainSupported(chainId, endpointId);
    }

    /**
     * @notice Updates the adapter address for an existing supported chain
     * @param chainId Chain ID in our system
     * @param adapterAddress New address of the StargateAdapter for this chain
     */
    function updateChainAdapter(
        uint16 chainId,
        address adapterAddress
    ) external onlyOwner {
        if (chainToEndpointId[chainId] == 0) revert InvalidParams();

        chainToAdapter[chainId] = adapterAddress;
    }

    /**
     * @notice Adds support for an asset on a specific chain
     * @param asset Address of the asset to support
     * @param stargateContract Address of the Stargate V2 contract for this asset
     */
    function addSupportedAsset(
        address asset,
        address stargateContract
    ) external onlyOwner {
        if (asset == address(0) || stargateContract == address(0))
            revert InvalidParams();

        // Verify this is a valid Stargate V2 contract (only for current chain)
        try IStargate(stargateContract).stargateType() returns (
            IStargate.StargateType
        ) {
            // Valid Stargate V2 contract
        } catch {
            revert InvalidParams();
        }

        assetToStargateContract[asset] = stargateContract;

        emit AssetSupported(uint16(block.chainid), asset, stargateContract);
    }

    /**
     * @notice Updates the bridge router address
     * @param newBridgeRouter Address of the new bridge router
     */
    function setBridgeRouter(address newBridgeRouter) external onlyOwner {
        if (newBridgeRouter == address(0)) revert InvalidBridgeRouter();

        address oldRouter = bridgeRouter;
        bridgeRouter = newBridgeRouter;

        emit BridgeRouterUpdated(oldRouter, newBridgeRouter);
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function transferAsset(
        bytes32 operationId,
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        address keeper,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable override {
        // Store msg.value early
        uint256 providedFee = msg.value;

        // Only the BridgeRouter should call this function
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Check if destination chain is supported
        if (!supportsChain(destinationChainId)) revert UnsupportedChain();

        // Check if asset is supported on current chain
        if (assetToStargateContract[asset] == address(0))
            revert UnsupportedAsset();

        // Get the source chain Stargate contract
        address stargateContract = assetToStargateContract[asset];

        // Get destination adapter address
        address destinationAdapter = chainToAdapter[destinationChainId];
        if (destinationAdapter == address(0)) revert UnsupportedChain();

        // Transfer tokens from BridgeRouter to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Approve Stargate contract to spend the tokens
        IERC20(asset).approve(stargateContract, 0);
        IERC20(asset).approve(stargateContract, amount);

        // Execute the Stargate V2 transfer
        TransferParams memory params = TransferParams({
            stargateContract: stargateContract,
            destinationChainId: destinationChainId,
            asset: asset,
            recipient: recipient,
            amount: amount,
            originator: originator,
            keeper: keeper,
            operationId: operationId
        });

        _executeSendToken(
            params,
            destinationAdapter,
            adapterParams,
            providedFee
        );

        // Emit the TransferInitiated event
        emit TransferInitiated(
            operationId,
            destinationChainId,
            asset,
            amount,
            recipient
        );

        IBridgeRouter(bridgeRouter).updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.SENT
        );
    }

    /**
     * @dev Execute the actual sendToken call
     */
    function _executeSendToken(
        TransferParams memory params,
        address destinationAdapter,
        BridgeTypes.AdapterParams calldata adapterParams,
        uint256 providedFee
    ) internal {
        IStargate stargate = IStargate(params.stargateContract);

        // Create compose message - ensure consistent encoding with lzCompose decoder
        bytes memory composeMsg = abi.encode(
            params.recipient, // FleetProxy address
            params.asset, // Asset being transferred
            params.amount, // Amount being transferred
            block.chainid, // Source chain ID (use block.chainid directly, not uint256())
            params.operationId, // Operation ID
            params.originator // Original sender
        );

        // Build SendParam - Stargate will wrap this with OFTComposeMsgCodec internally
        SendParam memory sendParam = _buildSendParam(
            params.destinationChainId,
            destinationAdapter,
            params.amount,
            composeMsg, // Just the custom message
            adapterParams
        );

        // Update minAmountLD based on quote
        _updateMinAmount(stargate, sendParam, params.amount);

        // Execute transfer
        _performTransfer(stargate, sendParam, params, providedFee);
    }

    /**
     * @dev Build SendParam struct
     */
    function _buildSendParam(
        uint16 destinationChainId,
        address destinationAdapter,
        uint256 amount,
        bytes memory composeMsg,
        BridgeTypes.AdapterParams calldata
    ) internal view returns (SendParam memory) {
        // Always use taxi mode for compose functionality and reliability
        bytes memory oftCmd = OftCmdHelper.taxi(); // Always use taxi mode like in the example

        // Add compose options when compose message is present
        bytes memory extraOptions = composeMsg.length > 0
            ? OptionsBuilder.newOptions().addExecutorLzComposeOption(
                0,
                uint128(composeGasLimit),
                0
            )
            : bytes("");

        return
            SendParam({
                dstEid: chainToEndpointId[destinationChainId],
                to: destinationAdapter.toBytes32(),
                amountLD: amount,
                minAmountLD: amount,
                extraOptions: extraOptions,
                composeMsg: composeMsg,
                oftCmd: oftCmd // Always "" for taxi mode
            });
    }

    /**
     * @dev Update minimum amount based on quote
     */
    function _updateMinAmount(
        IStargate stargate,
        SendParam memory sendParam,
        uint256 amount
    ) internal view {
        try stargate.quoteOFT(sendParam) returns (
            OFTLimit memory,
            OFTFeeDetail[] memory,
            OFTReceipt memory oftReceipt
        ) {
            sendParam.minAmountLD = oftReceipt.amountReceivedLD;
        } catch {
            sendParam.minAmountLD = (amount * 9950) / 10000;
        }
    }

    /**
     * @dev Perform the actual transfer
     */
    function _performTransfer(
        IStargate stargate,
        SendParam memory sendParam,
        TransferParams memory params,
        uint256 providedFee
    ) internal {
        MessagingFee memory messagingFee = stargate.quoteSend(sendParam, false);

        if (providedFee < messagingFee.nativeFee) {
            revert InsufficientFee(messagingFee.nativeFee, providedFee);
        }

        // Use exact fee amount from quote - Stargate handles refunds to keeper
        stargate.sendToken{value: messagingFee.nativeFee}(
            sendParam,
            messagingFee,
            params.keeper // Always refund to keeper who paid fees
        );
    }

    /**
     * @dev Determines transport mode based on adapter params
     */
    function _getTransportMode(
        BridgeTypes.AdapterParams calldata,
        bool
    ) internal pure returns (bytes memory) {
        // Always use taxi mode for cross-chain asset transfers
        // This aligns with the pattern shown in Stargate V2 examples
        // Taxi mode is more reliable and required for compose functionality
        return OftCmdHelper.taxi(); // Returns ""
    }

    /**
     * @dev Helper function to check if transport mode is taxi
     */
    function _isTaxiMode(bytes memory oftCmd) internal pure returns (bool) {
        return oftCmd.length == 0; // taxi() returns empty bytes, bus() returns bytes with length 1
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.AdapterParams calldata,
        BridgeTypes.OperationType operationType
    ) public view returns (uint256 nativeFee, uint256 tokenFee) {
        // Check if chain is supported
        if (!supportsChain(destinationChainId)) revert UnsupportedChain();

        // Check if asset is supported on current chain
        if (
            operationType == BridgeTypes.OperationType.TRANSFER_ASSET &&
            assetToStargateContract[asset] == address(0)
        ) {
            revert UnsupportedAsset();
        }

        // Get the source chain Stargate contract
        address stargateContract = assetToStargateContract[asset];

        // Always include compose options in fee estimation
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, uint128(composeGasLimit), 0);

        // Prepare SendParam for quote
        SendParam memory sendParam = SendParam({
            dstEid: chainToEndpointId[destinationChainId],
            to: address(0xdead).toBytes32(),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: extraOptions,
            composeMsg: abi.encode(
                uint16(block.chainid),
                bytes32(0),
                address(0)
            ), // Dummy compose message
            oftCmd: OftCmdHelper.taxi() // Always use taxi mode
        });

        // Get messaging fee quote
        try IStargate(stargateContract).quoteSend(sendParam, false) returns (
            MessagingFee memory msgFee
        ) {
            return (msgFee.nativeFee, 0); // Stargate V2 uses only native fees
        } catch {
            // Fallback estimation (higher due to compose overhead)
            return (0.015 ether, 0); // Conservative estimate with compose overhead
        }
    }

    /// @inheritdoc IBridgeAdapter
    function getOperationStatus(
        bytes32 operationId
    ) external view override returns (BridgeTypes.OperationStatus) {
        return IBridgeRouter(bridgeRouter).getOperationStatus(operationId);
    }

    /// @inheritdoc IBridgeAdapter
    function getSupportedChains()
        external
        view
        override
        returns (uint16[] memory)
    {
        return supportedChains;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsChain(uint16 chainId) public view override returns (bool) {
        return chainToAdapter[chainId] != address(0);
    }

    /**
     * @dev Helper function to check if an asset is supported on a specific chain
     */
    function isAssetSupported(
        uint16 chainId,
        address asset
    ) public view returns (bool) {
        if (chainId == uint16(block.chainid)) {
            // For current chain, check if asset has a Stargate contract
            return assetToStargateContract[asset] != address(0);
        } else {
            // For destination chains, check if we have an adapter address
            return chainToAdapter[chainId] != address(0);
        }
    }

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure override returns (bool) {
        // Stargate V2 only supports asset transfers
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /*//////////////////////////////////////////////////////////////
                      UNSUPPORTED OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function readState(
        bytes32,
        uint16,
        uint16,
        address,
        bytes4,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /// @inheritdoc ISendAdapter
    function sendMessage(
        bytes32,
        uint16,
        address,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles composed messages from LayerZero after Stargate token delivery
     * @dev Called by LayerZero endpoint after tokens are delivered via Stargate V2
     * @param _from The originating OApp (should be destination Stargate contract)
     * @param _message OFT-encoded compose message from Stargate
     */
    function lzCompose(
        address _from,
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) external payable override {
        // Verify caller is LayerZero endpoint
        if (msg.sender != lzEndpoint) {
            revert Unauthorized();
        }

        // Extract the amount and compose message from OFT encoding
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);

        // Decode compose message and handle the rest
        _handleComposedMessage(_from, amountLD, composeMsg);
    }

    /**
     * @dev Internal function to handle the composed message logic - SIMPLIFIED
     */
    function _handleComposedMessage(
        address _from,
        uint256 amountLD,
        bytes memory composeMsg
    ) internal {
        // Decode the compose message
        (
            address recipient,
            address sourceAsset,
            ,
            uint256 sourceChainId,
            bytes32 operationId,
            address originator
        ) = abi.decode(
                composeMsg,
                (address, address, uint256, uint256, bytes32, address)
            );

        // Get destination asset - SIMPLIFIED: fail fast if we can't get it
        address destinationAsset = IStargate(_from).token();

        // Basic validation - fail fast
        if (
            destinationAsset == address(0) ||
            recipient == address(0) ||
            amountLD == 0
        ) {
            revert InvalidParams();
        }

        // Check adapter balance
        uint256 adapterBalance = IERC20(destinationAsset).balanceOf(
            address(this)
        );
        if (adapterBalance < amountLD) {
            revert InsufficientBalance();
        }

        // Determine if this is a deposit or withdrawal based on recipient type
        bool isDeposit = _isFleetProxy(recipient);

        // Try to deliver assets - if it fails, hold them for governance recovery
        bool success = _tryDeliverAssets(
            recipient,
            destinationAsset,
            amountLD,
            operationId,
            originator,
            sourceAsset,
            uint16(sourceChainId)
        );

        if (!success) {
            // Store failed compose details for governance recovery
            failedComposes[operationId] = FailedCompose({
                asset: destinationAsset,
                amount: amountLD,
                intendedRecipient: recipient,
                operationId: operationId,
                originator: originator,
                sourceChainId: uint16(sourceChainId),
                timestamp: block.timestamp,
                isDeposit: isDeposit
            });

            failedOperationIds.push(operationId);

            emit ComposeFailedAssetsHeld(
                operationId,
                destinationAsset,
                amountLD,
                recipient,
                isDeposit,
                "Recipient call failed"
            );

            // Don't revert - just hold the assets for recovery
            return;
        }

        emit ComposedAssetHandled(
            operationId,
            recipient,
            destinationAsset,
            amountLD,
            uint16(sourceChainId)
        );
    }

    /**
     * @dev Try to deliver assets to recipient without reverting on failure
     */
    function _tryDeliverAssets(
        address recipient,
        address asset,
        uint256 amount,
        bytes32 operationId,
        address originator,
        address sourceAsset,
        uint16 sourceChainId
    ) internal returns (bool success) {
        // Transfer tokens first
        IERC20(asset).safeTransfer(recipient, amount);

        // Try to call recipient - return false if it fails
        try
            ICrossChainAssetReceiver(recipient).receiveMessageWithAssets(
                asset,
                amount,
                abi.encode(operationId, originator, sourceAsset),
                sourceChainId
            )
        {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @dev Check if an address is a FleetProxy (vs CrossChainArk)
     * @dev This helps determine the recovery strategy
     * @dev FleetProxy: supports ICrossChainAssetReceiver but NOT ICrossChainArk
     * @dev CrossChainArk: supports both ICrossChainAssetReceiver AND ICrossChainArk
     */
    function _isFleetProxy(address recipient) internal view returns (bool) {
        // If it supports ICrossChainArk, it's a CrossChainArk, not a FleetProxy
        try
            IERC165(recipient).supportsInterface(
                type(ICrossChainArk).interfaceId
            )
        returns (bool supportsArk) {
            if (supportsArk) {
                return false; // It's a CrossChainArk
            }
        } catch {
            // If we can't check, assume it's not a CrossChainArk
        }

        // Check if it supports ICrossChainAssetReceiver (both FleetProxy and CrossChainArk do)
        // But we already ruled out CrossChainArk above, so if it supports this, it's likely a FleetProxy
        try
            IERC165(recipient).supportsInterface(
                type(ICrossChainAssetReceiver).interfaceId
            )
        returns (bool supportsReceiver) {
            return supportsReceiver;
        } catch {
            return false; // Can't determine, assume not a FleetProxy
        }
    }

    /**
     * @notice Get the LayerZero Endpoint ID for a given chain
     */
    function getEndpointId(uint16 chainId) external view returns (uint32) {
        return chainToEndpointId[chainId];
    }

    /**
     * @notice Manual recovery for edge cases
     * @dev When automated recovery isn't possible, governance can manually send assets
     * @param asset Token to recover
     * @param amount Amount to recover
     * @param recipient Where to send the tokens
     * @param operationId Operation ID to clear (optional)
     * @param tryReceiveCall Whether to attempt receiveMessageWithAssets call
     * @param customMessage Custom message for receiveMessageWithAssets (if tryReceiveCall is true)
     */
    function manualRecovery(
        address asset,
        uint256 amount,
        address recipient,
        bytes32 operationId,
        bool tryReceiveCall,
        bytes calldata customMessage
    ) external onlyOwner {
        if (recipient == address(0)) revert InvalidParams();

        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        IERC20(asset).safeTransfer(recipient, amount);

        // Optionally try the receive call with custom message
        if (tryReceiveCall) {
            try
                ICrossChainAssetReceiver(recipient).receiveMessageWithAssets(
                    asset,
                    amount,
                    customMessage,
                    uint16(block.chainid) // Use current chain as source for manual recovery
                )
            {
                // Success - call completed
            } catch (bytes memory reason) {
                // Log failure but continue - tokens were already sent
                emit ComposeCallFailed(operationId, recipient, reason);
            }
        }

        // Clear failed compose record if provided
        if (operationId != bytes32(0)) {
            delete failedComposes[operationId];

            // Remove from failed operation IDs array
            for (uint256 i = 0; i < failedOperationIds.length; i++) {
                if (failedOperationIds[i] == operationId) {
                    // Move last element to this position and pop
                    failedOperationIds[i] = failedOperationIds[
                        failedOperationIds.length - 1
                    ];
                    failedOperationIds.pop();
                    break;
                }
            }
        }

        emit TokensRecovered(asset, amount, recipient);
    }

    /**
     * @notice Get all failed compose operations
     * @return Array of failed operation IDs
     */
    function getFailedOperations() external view returns (bytes32[] memory) {
        return failedOperationIds;
    }

    /**
     * @notice Get details of a specific failed operation
     * @param operationId Operation ID to query
     * @return Failed compose details
     */
    function getFailedCompose(
        bytes32 operationId
    ) external view returns (FailedCompose memory) {
        return failedComposes[operationId];
    }

    /**
     * @notice Debug function to check adapter's token balance
     * @param asset Token address to check
     * @return Current balance of the asset in this adapter
     */
    function getAdapterBalance(address asset) external view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }
}
