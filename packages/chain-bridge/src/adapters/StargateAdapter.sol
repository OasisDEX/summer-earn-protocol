// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/// forge-lint: disable-start(unused-import)
import {IBridgeAdapter, ISendAdapter} from "../interfaces/IBridgeAdapter.sol";
/// forge-lint: disable-end(unused-import)
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ICrossChainAssetReceiver} from "../interfaces/ICrossChainAssetReceiver.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {BaseBridgeAdapter} from "./BaseBridgeAdapter.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {MessagingFee, OFTFeeDetail, OFTLimit, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SummerTaxiCodec} from "../libraries/SummerTaxiCodec.sol";

import {IStargateV2} from "../interfaces/IStargateV2.sol";
import {OftCmdHelper} from "../libraries/OftCmdHelper.sol";

/**
 * @title StargateAdapter
 * @notice Adapter for Stargate V2 Protocol - all V2 contracts are OFT-enabled
 * @dev Implements IBridgeAdapter interface and connects to Stargate V2 for efficient cross-chain transfers
 */
contract StargateAdapter is
    IBridgeAdapter,
    ILayerZeroComposer,
    Nonces,
    BaseBridgeAdapter
{
    using SafeERC20 for IERC20;
    using AddressCast for address;
    using OptionsBuilder for bytes;

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

    /// @notice LayerZero endpoint for compose functionality
    address public immutable LZ_ENDPOINT;

    /// @notice Mapping of supported chains to their LayerZero Endpoint IDs
    mapping(uint16 chainId => uint32 lzEid) public chainToLzEid;

    /// @notice Mapping of assets to their Stargate contracts on THIS chain only
    mapping(address asset => address stargateContract)
        public assetToStargateContract;

    /// @notice Default transport mode (true = taxi, false = bus)
    /// @dev Taxi mode is required for composability - bus mode does not support compose
    bool public defaultUseTaxi = true;

    /// @notice Maximum slippage tolerance (10% = 1000 basis points)
    uint256 public constant MAX_SLIPPAGE_BPS = 1000;

    /// @notice Minimum slippage tolerance (0.01% = 1 basis point)
    uint256 public constant MIN_SLIPPAGE_BPS = 1;

    /// @notice Default slippage tolerance in basis points (0.5% = 50 basis points)
    uint256 public slippageToleranceBps = 50;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an endpoint ID is set
    event EndpointIdSet(uint16 chainId, uint32 endpointId);

    /// @notice Emitted when an asset support is added
    event AssetSupported(
        uint16 chainId,
        address asset,
        address stargateContract
    );

    /// @notice Emitted when default transport mode is changed
    event DefaultTransportModeChanged(bool useTaxi);

    /// @notice Emitted when slippage tolerance is updated
    event SlippageToleranceUpdated(uint256 newSlippageBps);

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

    /// @notice Emitted when compose call fails (alternate version with source chain)
    event ComposeCallFailedWithSource(
        bytes32 indexed operationId,
        address indexed fleetProxy,
        uint16 sourceChainId
    );

    /// @notice Emitted when stuck tokens are recovered
    event TokensRecovered(
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the StargateAdapter
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _accessManager Address of the AccessManager contract
     * @param _lzEndpoint LayerZero endpoint for compose functionality
     * @param _harborCommand Address of the HarborCommand contract for fleet commander validation
     */
    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint,
        address _harborCommand
    ) BaseBridgeAdapter(_crossChainRegistry, _accessManager) {
        if (_lzEndpoint == address(0)) revert InvalidParams();
        if (_harborCommand == address(0)) revert InvalidParams();

        LZ_ENDPOINT = _lzEndpoint;
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the default transport mode
     * @param _useTaxi True for taxi mode (immediate), false for bus mode (batched)
     */
    function setDefaultTransportMode(bool _useTaxi) external onlyGovernor {
        defaultUseTaxi = _useTaxi;
        emit DefaultTransportModeChanged(_useTaxi);
    }

    /**
     * @notice Sets the slippage tolerance for fallback minimum amount calculation
     * @param _slippageBps New slippage tolerance in basis points (e.g., 50 = 0.5%)
     */
    function setSlippageTolerance(uint256 _slippageBps) external onlyGovernor {
        if (
            _slippageBps < MIN_SLIPPAGE_BPS || _slippageBps > MAX_SLIPPAGE_BPS
        ) {
            revert InvalidParams();
        }
        slippageToleranceBps = _slippageBps;
        emit SlippageToleranceUpdated(_slippageBps);
    }

    /**
     * @notice Sets the LayerZero endpoint ID for a chain
     * @param chainId Chain ID in our system
     * @param lzEid Corresponding LayerZero Endpoint ID
     */
    function addSupportedChain(
        uint16 chainId,
        uint32 lzEid
    ) external onlyGovernor {
        if (lzEid == 0) {
            revert InvalidParams();
        }

        chainToLzEid[chainId] = lzEid;
        emit EndpointIdSet(chainId, lzEid);
    }

    /**
     * @notice Removes a supported chain
     * @param chainId Chain ID to remove
     * @dev Can only be called by the contract owner
     */
    function removeSupportedChain(uint16 chainId) external onlyGovernor {
        delete chainToLzEid[chainId];
        emit EndpointIdSet(chainId, 0);
    }

    /**
     * @notice Adds support for an asset on a specific chain
     * @param asset Address of the asset to support
     * @param stargateContract Address of the Stargate V2 contract for this asset
     */
    function addSupportedAsset(
        address asset,
        address stargateContract
    ) external onlyGovernor {
        if (asset == address(0) || stargateContract == address(0)) {
            revert InvalidParams();
        }

        // Verify this is a valid Stargate V2 contract (only for current chain)
        try IStargateV2(stargateContract).stargateType() returns (
            IStargateV2.StargateType
        ) {
            // Valid Stargate V2 contract
        } catch {
            revert InvalidParams();
        }

        assetToStargateContract[asset] = stargateContract;

        emit AssetSupported(uint16(block.chainid), asset, stargateContract);
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function transferAsset(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata
    )
        external
        payable
        onlySupportedDestination(params.destinationChainId)
        onlyRouter
        nonReentrant
    {
        uint256 providedFee = msg.value;

        // Check if asset is supported on current chain
        if (assetToStargateContract[params.asset] == address(0)) {
            revert UnsupportedAsset();
        }

        // Transfer tokens from BridgeRouter to this contract
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        );

        _executeSendToken(operationId, params, providedFee);

        // Emit the TransferInitiated event
        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.target
        );
    }

    /**
     * @dev Execute the actual sendToken call
     */
    function _executeSendToken(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams memory params,
        uint256 providedFee
    ) internal {
        // Get the source chain Stargate contract
        address stargateContract = assetToStargateContract[params.asset];
        IStargateV2 stargate = IStargateV2(stargateContract);

        // Approve Stargate contract to spend the tokens
        IERC20(params.asset).forceApprove(stargateContract, params.amount);

        // Resolve destination adapter via registry
        address destinationAdapter = _peerAdapter(params.destinationChainId);
        if (destinationAdapter == address(0)) revert UnsupportedChain();

        BridgeTypes.ReceiveTransferParams memory atm = BridgeTypes
            .ReceiveTransferParams({
                recipient: params.target,
                asset: params.asset,
                amount: params.amount,
                sourceChainId: uint16(block.chainid),
                operationId: operationId,
                originator: params.originator,
                message: params.message
            });

        // Build SendParam - Stargate will wrap this with OFTComposeMsgCodec internally
        SendParam memory sendParam = _buildSendParam(
            params.destinationChainId,
            destinationAdapter,
            params.amount,
            abi.encode(atm)
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
        bytes memory composeMsg
    ) internal view returns (SendParam memory) {
        // Always use taxi mode for compose functionality and reliability
        bytes memory oftCmd = OftCmdHelper.taxi(); // Always use taxi mode like in the example

        // Add compose options when compose message is present
        bytes memory extraOptions = composeMsg.length > 0
            ? OptionsBuilder.newOptions().addExecutorLzComposeOption(
                0,
                uint128(defaultGasLimit()),
                0
            )
            : bytes("");

        return
            SendParam({
                dstEid: chainToLzEid[destinationChainId],
                to: destinationAdapter.toBytes32(),
                amountLD: amount,
                minAmountLD: amount,
                extraOptions: extraOptions,
                composeMsg: composeMsg,
                oftCmd: oftCmd // Always "" for taxi mode
            });
    }

    /**
     * @dev Update minimum amount based on quote with proper validation
     */
    function _updateMinAmount(
        IStargateV2 stargate,
        SendParam memory sendParam,
        uint256 amount
    ) internal view {
        (OFTLimit memory oftLimit, , OFTReceipt memory oftReceipt) = stargate
            .quoteOFT(sendParam);
        // Validate OFT limits first
        if (amount < oftLimit.minAmountLD) {
            revert InsufficientAmount(amount, oftLimit.minAmountLD);
        }
        if (amount > oftLimit.maxAmountLD) {
            revert ExceedsMaxAmount(amount, oftLimit.maxAmountLD);
        }

        // Validate received amount
        if (oftReceipt.amountReceivedLD == 0) {
            revert ZeroAmountReceived();
        }

        // Check that received amount is not higher than input (suspicious)
        if (oftReceipt.amountReceivedLD > amount) {
            revert InvalidAmountReceived(oftReceipt.amountReceivedLD, amount);
        }

        // Calculate minimum slippage threshold (use configurable tolerance)
        uint256 minExpectedAmount = (amount * (10000 - slippageToleranceBps)) /
            10000;

        // Revert if slippage exceeds tolerance
        if (oftReceipt.amountReceivedLD < minExpectedAmount) {
            revert SlippageExceedsTolerance(
                minExpectedAmount,
                oftReceipt.amountReceivedLD,
                slippageToleranceBps
            );
        }

        // Use the quoted amount since it's within tolerance
        sendParam.minAmountLD = oftReceipt.amountReceivedLD;
    }

    /**
     * @dev Perform the actual transfer
     */
    function _performTransfer(
        IStargateV2 stargate,
        SendParam memory sendParam,
        BridgeTypes.ExecuteTransferParams memory params,
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
            params.refundAddress // Always refund to keeper who paid fees
        );
    }

    /**
     * @dev Determines transport mode based on adapter params
     */
    function _getTransportMode(
        BridgeTypes.BridgeOptions calldata,
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
        uint16 dstChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.OperationType operationType
    )
        public
        view
        onlySupportedDestination(dstChainId)
        returns (uint256 nativeFee, uint256 tokenFee)
    {
        // Check if asset is supported on current chain
        if (
            operationType == BridgeTypes.OperationType.TRANSFER_ASSET &&
            assetToStargateContract[asset] == address(0)
        ) {
            revert UnsupportedAsset();
        }

        // Get the source chain Stargate contract
        address stargateContract = assetToStargateContract[asset];

        // Use compose gas limit from adapter params if provided, otherwise use default
        uint256 gasLimit = options.gasLimit > 0
            ? options.gasLimit
            : defaultGasLimit();

        // Always include compose options in fee estimation
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, uint128(gasLimit), 0);

        // Check if a compose message is provided in adapter params
        bytes memory composeMsg;
        if (options.options.length > 0) {
            // Use the provided compose message for accurate fee estimation
            composeMsg = options.options;
        } else {
            // Fall back to dummy compose message for legacy compatibility
            composeMsg = abi.encode(
                uint16(block.chainid),
                bytes32(0),
                address(0)
            );
        }

        // Prepare SendParam for quote
        SendParam memory sendParam = SendParam({
            dstEid: chainToLzEid[dstChainId],
            to: address(0xdead).toBytes32(),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: OftCmdHelper.taxi() // Always use taxi mode
        });

        // Get messaging fee quote
        try IStargateV2(stargateContract).quoteSend(sendParam, false) returns (
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
        return IBridgeRouter(bridgeRouter()).getOperationStatus(operationId);
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
        }
        return _peerAdapter(chainId) != address(0);
    }

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure override returns (bool) {
        // Stargate V2 supports asset transfers
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /*//////////////////////////////////////////////////////////////
                      UNSUPPORTED OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function readState(
        bytes32,
        BridgeTypes.ExecuteReadStateParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /// @inheritdoc ISendAdapter
    function sendMessage(
        bytes32,
        BridgeTypes.ExecuteSendMessageParams calldata,
        BridgeTypes.BridgeOptions calldata
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
        bytes32, // guid
        bytes calldata _message,
        address, // caller
        bytes calldata // extraData
    ) external payable override nonReentrant {
        // Verify caller is LayerZero endpoint
        if (msg.sender != LZ_ENDPOINT) revert Unauthorized();

        // Validate the Stargate pool contract
        _validateStargatePool(_from);

        // ---------------------------------------------------------------
        // 1. Taxi header must be present
        // ---------------------------------------------------------------
        if (!SummerTaxiCodec.isTaxi(_message)) revert InvalidMessage();

        // Decode taxi message (includes srcSender & compose payload)
        (, , , address srcSender, bytes memory composeMsg) = SummerTaxiCodec
            .decodeTaxi(_message);

        // ---------------------------------------------------------------
        // 2. Verify peer adapter relationship
        // ---------------------------------------------------------------
        BridgeTypes.ReceiveTransferParams memory atm = abi.decode(
            composeMsg,
            (BridgeTypes.ReceiveTransferParams)
        );

        _assertTrustedSource(srcSender, uint16(atm.sourceChainId));

        // ---------------------------------------------------------------
        // 3. Continue normal handling (the SD amount from the Taxi header is
        // informational; the real LD amount lives inside the composeMsg)
        // ---------------------------------------------------------------
        _handleComposedMessage(_from, composeMsg);
    }

    /**
     * @dev Validates that a contract is a legitimate registered Stargate V2 pool
     * @param _from Address of the contract to validate
     * @return token The ERC20 token handled by this Stargate pool
     * @dev Reverts with Untrusted if validation fails
     */
    function _validateStargatePool(
        address _from
    ) internal view returns (address token) {
        // 1. Verify _from is a valid Stargate V2 contract by checking token() call
        try IStargateV2(_from).token() returns (address _token) {
            token = _token;
        } catch {
            // If token() call fails, this is not a valid Stargate V2 contract
            revert Untrusted("Stargate pool", _from, address(0));
        }

        // 2. Verify this exact Stargate contract is registered for this token
        if (assetToStargateContract[token] != _from) {
            revert Untrusted("Stargate pool", _from, token);
        }

        return token;
    }

    /**
     * @dev Internal function to handle the composed message logic - EXTENDED for Fleet Deposits
     */
    function _handleComposedMessage(
        address _from,
        bytes memory composeMsg
    ) internal {
        // Get the received asset from the Stargate contract
        address receivedAsset = IStargateV2(_from).token();

        _handleAssetTransferMessage(receivedAsset, composeMsg);
    }

    /**
     * @dev Handle asset transfer compose messages
     */
    function _handleAssetTransferMessage(
        address receivedAsset,
        bytes memory composeMsg
    ) internal {
        // Decode the compose message
        BridgeTypes.ReceiveTransferParams memory atm = abi.decode(
            composeMsg,
            (BridgeTypes.ReceiveTransferParams)
        );

        // -----------------------------------------------------------------
        // 1. Forward the tokens the adapter just received to the router
        // -----------------------------------------------------------------
        IERC20(receivedAsset).safeTransfer(bridgeRouter(), atm.amount);

        // -----------------------------------------------------------------
        // 3. Let the BridgeRouter finish the delivery
        // -----------------------------------------------------------------
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            composeMsg
        );
    }

    /**
     * @notice Get the LayerZero Endpoint ID for a given chain
     */
    function getEndpointId(uint16 chainId) external view returns (uint32) {
        return chainToLzEid[chainId];
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
    ) external onlyGovernor nonReentrant {
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
