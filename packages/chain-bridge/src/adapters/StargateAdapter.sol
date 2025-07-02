// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {IFleetDepositAdapter} from "../interfaces/IFleetDepositAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICrossChainAssetReceiver} from "../interfaces/ICrossChainAssetReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

// Import CrossChain Ark interface for proper detection
import {ICrossChainArk} from "../interfaces/ICrossChainArk.sol";

// Stargate V2 interfaces - based on LayerZero V2 OFT standard
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt, OFTLimit, OFTFeeDetail} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
// Add LayerZero composability imports
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

// Import interfaces
import {IFleetCommanderMinimal} from "../interfaces/IFleetCommanderMinimal.sol";
import {IStargateV2} from "../interfaces/IStargateV2.sol";
import {OftCmdHelper} from "../libraries/OftCmdHelper.sol";
import {IHarborCommandMinimal} from "../interfaces/IHarborCommandMinimal.sol";

/**
 * @title StargateAdapter
 * @notice Adapter for Stargate V2 Protocol - all V2 contracts are OFT-enabled
 * @dev Implements IBridgeAdapter interface and connects to Stargate V2 for efficient cross-chain transfers
 */
contract StargateAdapter is
    Ownable,
    IBridgeAdapter,
    IFleetDepositAdapter,
    ILayerZeroComposer,
    Nonces
{
    using SafeERC20 for IERC20;
    using AddressCast for address;
    using OptionsBuilder for bytes;

    /// @notice Error for unsupported asset
    error UnsupportedAsset();

    /// @notice Error for insufficient balance
    error InsufficientBalance();

    /// @notice Error for invalid fleet commander
    error InvalidFleetCommander();

    /// @notice Error for amount below minimum limit
    error InsufficientAmount(uint256 amount, uint256 minAmount);

    /// @notice Error for amount above maximum limit
    error ExceedsMaxAmount(uint256 amount, uint256 maxAmount);

    /// @notice Error for zero amount received
    error ZeroAmountReceived();

    /// @notice Error for invalid amount received
    error InvalidAmountReceived(uint256 received, uint256 input);

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

    /// @notice HarborCommand contract address for fleet commander validation
    address public immutable harborCommand;

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

    /// @notice Maximum slippage tolerance (10% = 1000 basis points)
    uint256 public constant MAX_SLIPPAGE_BPS = 1000;

    /// @notice Minimum slippage tolerance (0.01% = 1 basis point)
    uint256 public constant MIN_SLIPPAGE_BPS = 1;

    /// @notice Default slippage tolerance in basis points (0.5% = 50 basis points)
    uint256 public slippageToleranceBps = 50;

    /// @notice Compose message types
    bytes32 public constant FLEET_DEPOSIT_TYPE = keccak256("FLEET_DEPOSIT");
    bytes32 public constant ASSET_TRANSFER_TYPE = keccak256("ASSET_TRANSFER");

    /// @notice Structure to hold decoded fleet deposit message data
    struct FleetDepositMessageData {
        /// @notice Type of message being sent (e.g., FLEET_DEPOSIT_TYPE)
        bytes32 messageType;
        /// @notice Address of the FleetCommander contract that will receive the deposit
        address fleetCommander;
        /// @notice Address that will receive the fleet shares from the deposit
        address shareRecipient;
        /// @notice Token contract address being deposited
        address asset;
        /// @notice Amount of tokens being deposited
        uint256 amount;
        /// @notice Chain ID where the deposit transaction was originally initiated
        uint256 sourceChainId;
        /// @notice Unique identifier for this cross-chain operation
        bytes32 operationId;
        /// @notice Address of the user who originally initiated the cross-chain deposit transaction
        /// @dev Used to distinguish user-led transactions (originalUser == shareRecipient) from system transactions
        /// @dev In case of deposit failure, determines whether to refund to user or hold for governance recovery
        address originalUser;
        /// @notice Optional referral code for tracking deposit attribution
        bytes referralCode;
    }

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

    /// @notice Emitted when a cross-chain fleet deposit is completed
    event CrossChainFleetDepositCompleted(
        bytes32 indexed operationId,
        address indexed fleetCommander,
        address indexed shareRecipient,
        address asset,
        uint256 amount,
        uint256 shares,
        uint16 sourceChainId
    );

    /// @notice Emitted when a cross-chain fleet deposit fails
    event CrossChainFleetDepositFailed(
        bytes32 indexed operationId,
        address indexed fleetCommander,
        address asset,
        uint256 amount,
        string reason
    );

    /// @notice Emitted when a user refund is issued
    event UserRefundIssued(
        bytes32 indexed operationId,
        address indexed asset,
        uint256 amount,
        address indexed user,
        address originalUser,
        uint16 sourceChainId,
        string reason
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the StargateAdapter
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _owner Address of the contract owner
     * @param _lzEndpoint LayerZero endpoint for compose functionality
     * @param _harborCommand Address of the HarborCommand contract for fleet commander validation
     */
    constructor(
        address _bridgeRouter,
        address _owner,
        address _lzEndpoint,
        address _harborCommand
    ) Ownable(_owner) {
        if (_bridgeRouter == address(0)) revert InvalidParams();
        if (_lzEndpoint == address(0)) revert InvalidParams();
        if (_harborCommand == address(0)) revert InvalidParams();

        bridgeRouter = _bridgeRouter;
        lzEndpoint = _lzEndpoint;
        harborCommand = _harborCommand;
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
     * @notice Sets the slippage tolerance for fallback minimum amount calculation
     * @param _slippageBps New slippage tolerance in basis points (e.g., 50 = 0.5%)
     */
    function setSlippageTolerance(uint256 _slippageBps) external onlyOwner {
        if (
            _slippageBps < MIN_SLIPPAGE_BPS || _slippageBps > MAX_SLIPPAGE_BPS
        ) {
            revert InvalidParams();
        }
        slippageToleranceBps = _slippageBps;
        emit SlippageToleranceUpdated(_slippageBps);
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

    /*//////////////////////////////////////////////////////////////
                    FLEET DEPOSIT ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetDepositAdapter
    function sendFleetDepositToDestinationChain(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address destinationAdapter,
        bytes memory composeMessage,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable override returns (bytes32 operationId) {
        // Validate inputs
        if (amount == 0) revert InvalidFleetDepositParams();

        // Check if destination chain is supported
        if (!supportsChain(destinationChainId)) revert UnsupportedChain();

        // Check if asset is supported on current chain
        if (assetToStargateContract[asset] == address(0))
            revert UnsupportedAsset();

        // Get destination adapter from mapping (just like in transferAsset)
        address actualDestinationAdapter = chainToAdapter[destinationChainId];
        if (actualDestinationAdapter == address(0)) revert UnsupportedChain();

        // Transfer tokens from user to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Generate operation ID with nonce for uniqueness
        uint256 nonce = _useNonce(msg.sender);
        operationId = keccak256(
            abi.encode(
                msg.sender,
                destinationChainId,
                amount,
                nonce,
                block.chainid
            )
        );

        // Extract data from compose message using the decode helper
        FleetDepositMessageData memory messageData = _decodeFleetDepositMessage(
            composeMessage
        );

        // Update operation ID and re-encode message
        messageData.operationId = operationId;
        bytes memory updatedComposeMessage = _encodeFleetDepositMessage(
            messageData
        );

        // Execute cross-chain transfer with compose
        _sendFleetDepositToDestinationChain(
            asset,
            amount,
            destinationChainId,
            actualDestinationAdapter,
            updatedComposeMessage,
            msg.value
        );

        emit FleetDepositSentToDestination(
            operationId,
            destinationChainId,
            msg.sender,
            messageData.fleetCommander,
            asset,
            amount,
            messageData.shareRecipient,
            address(this)
        );
    }

    /// @inheritdoc IFleetDepositAdapter
    function supportsUserInitiatedFleetDeposits()
        external
        pure
        override
        returns (bool)
    {
        return true;
    }

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
        IERC20(asset).forceApprove(stargateContract, amount);

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
     * @dev Send fleet deposit to destination chain using Stargate
     */
    function _sendFleetDepositToDestinationChain(
        address asset,
        uint256 amount,
        uint16 destinationChainId,
        address destinationAdapter,
        bytes memory composeMsg,
        uint256 providedFee
    ) internal {
        address stargateContract = assetToStargateContract[asset];
        IStargateV2 stargate = IStargateV2(stargateContract);

        // Approve Stargate contract to spend the tokens
        IERC20(asset).approve(stargateContract, 0);
        IERC20(asset).approve(stargateContract, amount);

        // Build SendParam for fleet deposit
        SendParam memory sendParam = _buildFleetDepositSendParam(
            destinationChainId,
            destinationAdapter,
            amount,
            composeMsg
        );

        // Update minAmountLD based on quote
        _updateMinAmount(stargate, sendParam, amount);

        // Execute transfer
        _performTransfer(
            stargate,
            sendParam,
            TransferParams({
                stargateContract: stargateContract,
                destinationChainId: destinationChainId,
                asset: asset,
                recipient: destinationAdapter,
                amount: amount,
                originator: msg.sender,
                keeper: msg.sender,
                operationId: bytes32(0) // Will be in compose message
            }),
            providedFee
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
        IStargateV2 stargate = IStargateV2(params.stargateContract);

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
     * @dev Build SendParam struct for fleet deposits
     */
    function _buildFleetDepositSendParam(
        uint16 destinationChainId,
        address destinationAdapter,
        uint256 amount,
        bytes memory composeMsg
    ) internal view returns (SendParam memory) {
        // Always use taxi mode for compose functionality
        bytes memory oftCmd = OftCmdHelper.taxi();

        // Add compose options for fleet deposit
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, uint128(composeGasLimit), 0);

        return
            SendParam({
                dstEid: chainToEndpointId[destinationChainId],
                to: destinationAdapter.toBytes32(),
                amountLD: amount,
                minAmountLD: amount,
                extraOptions: extraOptions,
                composeMsg: composeMsg,
                oftCmd: oftCmd
            });
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
     * @dev Update minimum amount based on quote with proper validation
     */
    function _updateMinAmount(
        IStargateV2 stargate,
        SendParam memory sendParam,
        uint256 amount
    ) internal view {
        try stargate.quoteOFT(sendParam) returns (
            OFTLimit memory oftLimit,
            OFTFeeDetail[] memory,
            OFTReceipt memory oftReceipt
        ) {
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
                revert InvalidAmountReceived(
                    oftReceipt.amountReceivedLD,
                    amount
                );
            }

            // Calculate minimum slippage threshold (use configurable tolerance)
            uint256 minExpectedAmount = (amount *
                (10000 - slippageToleranceBps)) / 10000;

            // Ensure received amount is within acceptable slippage
            if (oftReceipt.amountReceivedLD < minExpectedAmount) {
                // Use fallback calculation instead of the quote
                sendParam.minAmountLD = minExpectedAmount;
            } else {
                // Use the quoted amount if it's reasonable
                sendParam.minAmountLD = oftReceipt.amountReceivedLD;
            }
        } catch {
            // Use configurable slippage tolerance as fallback
            sendParam.minAmountLD =
                (amount * (10000 - slippageToleranceBps)) /
                10000;
        }
    }

    /**
     * @dev Perform the actual transfer
     */
    function _performTransfer(
        IStargateV2 stargate,
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
        BridgeTypes.AdapterParams calldata adapterParams,
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

        // Use compose gas limit from adapter params if provided, otherwise use default
        uint256 gasLimit = adapterParams.gasLimit > 0
            ? adapterParams.gasLimit
            : composeGasLimit;

        // Always include compose options in fee estimation
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, uint128(gasLimit), 0);

        // Check if a compose message is provided in adapter params
        bytes memory composeMsg;
        if (adapterParams.options.length > 0) {
            // Use the provided compose message for accurate fee estimation
            composeMsg = adapterParams.options;
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
            dstEid: chainToEndpointId[destinationChainId],
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
        address, // keeper
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
        address, // keeper
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
     * @dev Decode fleet deposit compose message
     * @param composeMessage The encoded compose message
     * @return Decoded message data
     */
    function _decodeFleetDepositMessage(
        bytes memory composeMessage
    ) internal pure returns (FleetDepositMessageData memory) {
        (
            bytes32 messageType,
            address fleetCommander,
            address shareRecipient,
            address asset,
            uint256 amount,
            uint256 sourceChainId,
            bytes32 operationId,
            address originalUser,
            bytes memory referralCode
        ) = abi.decode(
                composeMessage,
                (
                    bytes32,
                    address,
                    address,
                    address,
                    uint256,
                    uint256,
                    bytes32,
                    address,
                    bytes
                )
            );

        return
            FleetDepositMessageData({
                messageType: messageType,
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                asset: asset,
                amount: amount,
                sourceChainId: sourceChainId,
                operationId: operationId,
                originalUser: originalUser,
                referralCode: referralCode
            });
    }

    /**
     * @dev Encode fleet deposit compose message
     * @param data The message data to encode
     * @return Encoded compose message
     */
    function _encodeFleetDepositMessage(
        FleetDepositMessageData memory data
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                data.messageType,
                data.fleetCommander,
                data.shareRecipient,
                data.asset,
                data.amount,
                data.sourceChainId,
                data.operationId,
                data.originalUser,
                data.referralCode
            );
    }

    /**
     * @dev Internal function to handle the composed message logic - EXTENDED for Fleet Deposits
     */
    function _handleComposedMessage(
        address _from,
        uint256 amountLD,
        bytes memory composeMsg
    ) internal {
        // Get the received asset from the Stargate contract
        address receivedAsset = IStargateV2(_from).token();

        // Read the message type from the first parameter of the compose message
        bytes32 messageType;
        assembly {
            messageType := mload(add(composeMsg, 0x20))
        }

        if (messageType == FLEET_DEPOSIT_TYPE) {
            _handleFleetDepositMessage(amountLD, composeMsg, receivedAsset);
        } else {
            _handleLegacyAssetTransferMessage(
                amountLD,
                composeMsg,
                receivedAsset
            );
        }
    }

    /**
     * @dev Handle fleet deposit compose messages
     */
    function _handleFleetDepositMessage(
        uint256 amountLD,
        bytes memory composeMsg,
        address receivedAsset
    ) internal {
        // Decode fleet deposit message using helper function
        FleetDepositMessageData memory messageData = _decodeFleetDepositMessage(
            composeMsg
        );

        // Basic validation
        if (
            receivedAsset == address(0) ||
            messageData.fleetCommander == address(0) ||
            messageData.shareRecipient == address(0) ||
            messageData.amount == 0
        ) {
            revert InvalidParams();
        }

        // Check adapter balance
        uint256 adapterBalance = IERC20(receivedAsset).balanceOf(address(this));
        if (adapterBalance < amountLD) {
            revert InsufficientBalance();
        }

        // Try to deposit to FleetCommander
        bool success = _tryDepositToFleetCommander(
            messageData.fleetCommander,
            receivedAsset,
            amountLD,
            messageData.shareRecipient,
            messageData.referralCode,
            messageData.operationId,
            uint16(messageData.sourceChainId)
        );

        if (!success) {
            // Check if this is a user-led transaction (via FleetDepositManager)
            bool isUserLedTransaction = _isUserLedTransaction(
                messageData.originalUser,
                messageData.shareRecipient
            );

            if (isUserLedTransaction) {
                // For user-led transactions, send assets directly to the user on destination chain
                _handleUserLedFailure(
                    receivedAsset,
                    amountLD,
                    messageData.shareRecipient,
                    messageData.operationId,
                    messageData.originalUser,
                    uint16(messageData.sourceChainId)
                );
            } else {
                // For system transactions, keep current behavior - hold for governance recovery
                _handleSystemFailure(
                    receivedAsset,
                    amountLD,
                    messageData.fleetCommander,
                    messageData.operationId,
                    messageData.originalUser,
                    uint16(messageData.sourceChainId)
                );
            }
            return;
        }

        emit ComposedAssetHandled(
            messageData.operationId,
            messageData.fleetCommander,
            receivedAsset,
            amountLD,
            uint16(messageData.sourceChainId)
        );
    }

    /**
     * @dev Check if this is a user-led transaction vs system transaction
     * @param originalUser The user who initiated the transaction
     * @param shareRecipient The recipient of fleet shares
     * @return True if this appears to be a user-led transaction
     */
    function _isUserLedTransaction(
        address originalUser,
        address shareRecipient
    ) internal pure returns (bool) {
        // User-led transactions typically have originalUser == shareRecipient
        // This indicates the user is depositing for themselves via FleetDepositManager
        return originalUser == shareRecipient && originalUser != address(0);
    }

    /**
     * @dev Handle failure for user-led transactions - send assets to user
     */
    function _handleUserLedFailure(
        address asset,
        uint256 amount,
        address user,
        bytes32 operationId,
        address originalUser,
        uint16 sourceChainId
    ) internal {
        // Send assets directly to the user on destination chain
        IERC20(asset).safeTransfer(user, amount);

        // Emit a specific event for user refunds first
        emit UserRefundIssued(
            operationId,
            asset,
            amount,
            user,
            originalUser,
            sourceChainId,
            "Fleet deposit failed"
        );

        emit CrossChainFleetDepositFailed(
            operationId,
            address(0), // fleetCommander - not applicable for user refund
            asset,
            amount,
            "Fleet deposit failed - assets sent to user"
        );
    }

    /**
     * @dev Handle failure for system transactions - hold for governance recovery
     */
    function _handleSystemFailure(
        address asset,
        uint256 amount,
        address intendedRecipient,
        bytes32 operationId,
        address originator,
        uint16 sourceChainId
    ) internal {
        // Store failed compose details for governance recovery (existing behavior)
        failedComposes[operationId] = FailedCompose({
            asset: asset,
            amount: amount,
            intendedRecipient: intendedRecipient,
            operationId: operationId,
            originator: originator,
            sourceChainId: sourceChainId,
            timestamp: block.timestamp,
            isDeposit: true
        });

        failedOperationIds.push(operationId);

        emit ComposeFailedAssetsHeld(
            operationId,
            asset,
            amount,
            intendedRecipient,
            true,
            "Fleet deposit failed - system transaction"
        );
    }

    /**
     * @dev Handle legacy asset transfer compose messages (existing functionality)
     */
    function _handleLegacyAssetTransferMessage(
        uint256 amountLD,
        bytes memory composeMsg,
        address receivedAsset
    ) internal {
        // Decode the compose message (legacy format)
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

        // Basic validation - fail fast
        if (
            receivedAsset == address(0) ||
            recipient == address(0) ||
            amountLD == 0
        ) {
            revert InvalidParams();
        }

        // Check adapter balance
        uint256 adapterBalance = IERC20(receivedAsset).balanceOf(address(this));
        if (adapterBalance < amountLD) {
            revert InsufficientBalance();
        }

        // Determine if this is a deposit or withdrawal based on recipient type
        bool isDeposit = _isFleetProxy(recipient);

        // Try to deliver assets - if it fails, hold them for governance recovery
        bool success = _tryDeliverAssets(
            recipient,
            receivedAsset,
            amountLD,
            operationId,
            originator,
            sourceAsset,
            uint16(sourceChainId)
        );

        if (!success) {
            // Store failed compose details for governance recovery
            failedComposes[operationId] = FailedCompose({
                asset: receivedAsset,
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
                receivedAsset,
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
            receivedAsset,
            amountLD,
            uint16(sourceChainId)
        );
    }

    /**
     * @dev Try to deposit assets to FleetCommander without reverting on failure
     */
    function _tryDepositToFleetCommander(
        address fleetCommander,
        address asset,
        uint256 amount,
        address shareRecipient,
        bytes memory referralCode,
        bytes32 operationId,
        uint16 sourceChainId
    ) internal returns (bool success) {
        // Validate FleetCommander is active through HarborCommand
        if (
            !IHarborCommandMinimal(harborCommand).activeFleetCommanders(
                fleetCommander
            )
        ) {
            emit CrossChainFleetDepositFailed(
                operationId,
                fleetCommander,
                asset,
                amount,
                "FleetCommander not active"
            );
            return false;
        }

        // Validate FleetCommander supports the asset
        address fleetAsset = IFleetCommanderMinimal(fleetCommander).asset();
        if (fleetAsset != asset) {
            emit CrossChainFleetDepositFailed(
                operationId,
                fleetCommander,
                asset,
                amount,
                "Asset mismatch"
            );
            return false;
        }

        // Check deposit limits
        uint256 maxDeposit = IFleetCommanderMinimal(fleetCommander).maxDeposit(
            address(this)
        );
        if (amount > maxDeposit) {
            emit CrossChainFleetDepositFailed(
                operationId,
                fleetCommander,
                asset,
                amount,
                "Exceeds max deposit"
            );
            return false;
        }

        // Approve FleetCommander to spend tokens
        IERC20(asset).approve(fleetCommander, amount);

        // Deposit to FleetCommander using helper methods
        uint256 shares;
        bool depositSuccess;

        if (referralCode.length > 0) {
            (depositSuccess, shares) = _executeFleetDepositWithReferral(
                fleetCommander,
                amount,
                shareRecipient,
                referralCode
            );
            if (!depositSuccess) {
                emit CrossChainFleetDepositFailed(
                    operationId,
                    fleetCommander,
                    asset,
                    amount,
                    "Deposit with referral failed"
                );
                return false;
            }
        } else {
            (depositSuccess, shares) = _executeFleetDepositWithoutReferral(
                fleetCommander,
                amount,
                shareRecipient
            );
            if (!depositSuccess) {
                emit CrossChainFleetDepositFailed(
                    operationId,
                    fleetCommander,
                    asset,
                    amount,
                    "Deposit failed"
                );
                return false;
            }
        }

        if (depositSuccess) {
            emit CrossChainFleetDepositCompleted(
                operationId,
                fleetCommander,
                shareRecipient,
                asset,
                amount,
                shares,
                sourceChainId
            );
            return true;
        }

        return false;
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
     * @dev Validates that a fleet commander is active through HarborCommand
     * @param fleetCommander Address of the fleet commander to validate
     * @dev Reverts with InvalidFleetCommander if fleet commander is not active
     */
    function _validateFleetCommander(address fleetCommander) internal view {
        if (
            !IHarborCommandMinimal(harborCommand).activeFleetCommanders(
                fleetCommander
            )
        ) {
            revert InvalidFleetCommander();
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

    /**
     * @dev Execute fleet deposit with referral code
     * @param fleetCommander Address of the fleet commander
     * @param amount Amount to deposit
     * @param shareRecipient Address to receive the shares
     * @param referralCode Referral code for the deposit
     * @return success Whether the deposit succeeded
     * @return shares Number of shares received (0 if failed)
     */
    function _executeFleetDepositWithReferral(
        address fleetCommander,
        uint256 amount,
        address shareRecipient,
        bytes memory referralCode
    ) internal returns (bool success, uint256 shares) {
        try
            IFleetCommanderMinimal(fleetCommander).deposit(
                amount,
                shareRecipient,
                referralCode
            )
        returns (uint256 _shares) {
            return (true, _shares);
        } catch {
            return (false, 0);
        }
    }

    /**
     * @dev Execute fleet deposit without referral code
     * @param fleetCommander Address of the fleet commander
     * @param amount Amount to deposit
     * @param shareRecipient Address to receive the shares
     * @return success Whether the deposit succeeded
     * @return shares Number of shares received (0 if failed)
     */
    function _executeFleetDepositWithoutReferral(
        address fleetCommander,
        uint256 amount,
        address shareRecipient
    ) internal returns (bool success, uint256 shares) {
        try
            IFleetCommanderMinimal(fleetCommander).deposit(
                amount,
                shareRecipient
            )
        returns (uint256 _shares) {
            return (true, _shares);
        } catch {
            return (false, 0);
        }
    }

    /**
     * @dev Deposit assets to validated FleetCommander - reverts on failure
     */
    function _depositToFleetCommander(
        address fleetCommander,
        address asset,
        uint256 amount,
        address shareRecipient,
        bytes memory referralCode,
        bytes32 operationId,
        uint16 sourceChainId
    ) internal {
        // Validate FleetCommander is active through HarborCommand
        _validateFleetCommander(fleetCommander);

        // Validate FleetCommander supports the asset
        address fleetAsset = IFleetCommanderMinimal(fleetCommander).asset();
        if (fleetAsset != asset) {
            revert InvalidParams();
        }

        // Check deposit limits
        uint256 maxDeposit = IFleetCommanderMinimal(fleetCommander).maxDeposit(
            address(this)
        );
        if (amount > maxDeposit) {
            revert InvalidParams();
        }

        // Approve FleetCommander to spend tokens
        IERC20(asset).approve(fleetCommander, amount);

        // Deposit to FleetCommander using helper methods
        uint256 shares;
        bool success;

        if (referralCode.length > 0) {
            (success, shares) = _executeFleetDepositWithReferral(
                fleetCommander,
                amount,
                shareRecipient,
                referralCode
            );
        } else {
            (success, shares) = _executeFleetDepositWithoutReferral(
                fleetCommander,
                amount,
                shareRecipient
            );
        }

        if (!success) {
            revert InvalidParams(); // Or a more specific error
        }

        emit CrossChainFleetDepositCompleted(
            operationId,
            fleetCommander,
            shareRecipient,
            asset,
            amount,
            shares,
            sourceChainId
        );
    }
}
