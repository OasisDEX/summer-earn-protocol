// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/// forge-lint: disable-start(unused-import)
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
/// forge-lint: disable-end(unused-import)
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ICrossChainReceiver} from "../interfaces/ICrossChainReceiver.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";
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
 * @dev Implements IAssetAdapter and IBridgeAdapter interfaces and connects to Stargate V2 for efficient cross-chain transfers
 */
contract StargateAdapter is
    IAssetAdapter,
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

    /// @notice Mapping of assets to their Stargate contracts on THIS chain only
    mapping(address asset => address stargateContract)
        public assetToStargateContract;

    /// @notice Mapping of Stargate contracts to their assets on THIS chain only
    mapping(address stargateContract => address asset)
        public stargateContractToAsset;

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
        bytes reason,
        uint16 sourceChainId
    );

    /// @notice Emitted when stuck tokens are recovered
    event TokensRecovered(
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when refunding excess native fee to `refundAddress` fails
    error RefundFailed(address recipient, uint256 amount);

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
            IStargateV2.StargateType stargateTypeValue
        ) {
            if (stargateTypeValue != IStargateV2.StargateType.Pool) {
                revert InvalidParams();
            }
        } catch {
            revert InvalidParams();
        }

        address stargatePoolToken = IStargateV2(stargateContract).token();
        if (stargatePoolToken != asset) {
            revert InvalidParams();
        }

        assetToStargateContract[asset] = stargateContract;
        stargateContractToAsset[stargateContract] = asset;

        emit AssetSupported(uint16(block.chainid), asset, stargateContract);
    }

    /**
     * @notice Map a new chain-id → endpoint-id pair for LayerZero endpoints.
     * @dev Governance utility. This only updates the local mapping; it does NOT
     *      grant permission to send. That second layer of permission is still
     *      enforced via the CrossChainRegistry.
     *
     * @param chainId     Canonical EVM chain ID.
     * @param endpointId  LayerZero endpoint identifier (EID).
     */
    function mapEndpoint(
        uint16 chainId,
        uint32 endpointId
    ) external onlyGovernor {
        if (endpointId == 0) {
            revert InvalidParams();
        }
        _mapChainExternalId(chainId, endpointId);
    }

    /**
     * @notice Delete the endpoint mapping for a chain.
     * @param chainId Chain ID whose mapping should be removed.
     */
    function unmapEndpoint(uint16 chainId) external onlyGovernor {
        _unmapChainExternalId(chainId);
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAssetAdapter
    function transferAsset(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyTrustedDestination(params.destinationChainId)
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

        _executeSendToken(operationId, params, providedFee, options);

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
     * @dev Execute the actual sendToken call with consolidated logic
     */
    function _executeSendToken(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams memory params,
        uint256 providedFee,
        BridgeTypes.BridgeOptions memory options
    ) internal {
        // Get the source chain Stargate contract
        address stargateContract = assetToStargateContract[params.asset];
        IStargateV2 stargate = IStargateV2(stargateContract);

        // Approve Stargate contract to spend the tokens
        IERC20(params.asset).forceApprove(stargateContract, params.amount);

        // Resolve destination adapter via registry
        address destinationAdapter = _peerAdapter(params.destinationChainId);

        // Build SendParam - Stargate will wrap this with OFTComposeMsgCodec internally
        SendParam memory sendParam = _buildSendParam(
            params.destinationChainId,
            destinationAdapter,
            params.amount,
            _encodeRelayedTransferParams(
                BridgeTypes.RelayedTransferParams({
                    recipient: params.target,
                    asset: params.asset,
                    amount: params.amount,
                    sourceChainId: uint16(block.chainid),
                    operationId: operationId,
                    originator: params.originator,
                    message: params.message
                })
            ),
            options
        );

        (OFTLimit memory oftLimit, , OFTReceipt memory oftReceipt) = stargate
            .quoteOFT(sendParam);

        // Calculate minimum slippage threshold (use configurable tolerance)
        uint256 minExpectedAmount = (params.amount *
            (10000 - slippageToleranceBps)) / 10000;

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

        // Get messaging fee and perform transfer
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

        // Refund any unused native value (buffer) back to the designated refund address
        uint256 refundAmount = providedFee - messagingFee.nativeFee;
        if (refundAmount > 0) {
            (bool ok, ) = params.refundAddress.call{value: refundAmount}("");
            if (!ok) revert RefundFailed(params.refundAddress, refundAmount);
        }
    }

    /**
     * @dev Helper function to create compose options with the given gas limit
     * @param gas Gas limit for the compose execution
     * @return Encoded options for LayerZero compose functionality
     */
    function _composeOptions(uint128 gas) internal pure returns (bytes memory) {
        return
            OptionsBuilder.newOptions().addExecutorLzComposeOption(0, gas, 0);
    }

    /**
     * @dev Build SendParam struct
     */
    function _buildSendParam(
        uint16 destinationChainId,
        address destinationAdapter,
        uint256 amount,
        bytes memory composeMsg,
        BridgeTypes.BridgeOptions memory options
    ) internal view returns (SendParam memory) {
        // Always use taxi mode for compose functionality and reliability
        bytes memory oftCmd = OftCmdHelper.taxi(); // Always use taxi mode like in the example

        // Add compose options when compose message is present
        bytes memory extraOptions = composeMsg.length > 0
            ? _composeOptions(uint128(_normalizeGas(options.gasLimit)))
            : bytes("");

        return
            SendParam({
                dstEid: chainToExternalId[destinationChainId],
                to: destinationAdapter.toBytes32(),
                amountLD: amount,
                minAmountLD: amount,
                extraOptions: extraOptions,
                composeMsg: composeMsg,
                oftCmd: oftCmd // Always "" for taxi mode
            });
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
        onlyTrustedDestination(dstChainId)
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
        uint256 gasLimit = _normalizeGas(options.gasLimit);

        // Always include compose options in fee estimation
        bytes memory extraOptions = _composeOptions(uint128(gasLimit));

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
            dstEid: chainToExternalId[dstChainId],
            to: address(0xdead).toBytes32(),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: OftCmdHelper.taxi() // Always use taxi mode
        });

        // Get messaging fee quote
        MessagingFee memory msgFee = IStargateV2(stargateContract).quoteSend(
            sendParam,
            false
        );
        return (msgFee.nativeFee, 0);
    }

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure override returns (bool) {
        // Stargate V2 supports asset transfers
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /// @inheritdoc IAssetAdapter
    function supportsAssetTransfer(
        uint16 destinationChainId,
        address asset
    ) external view returns (bool) {
        if (destinationChainId == uint16(block.chainid)) {
            // For current chain, check if asset has a Stargate contract
            return assetToStargateContract[asset] != address(0);
        }

        // For remote chains, require BOTH:
        // 1. Asset is supported locally (required for transferAsset to work)
        // 2. Peer adapter exists (required for cross-chain routing)
        // NOTE: This does NOT guarantee the destination adapter is configured properly.
        // A misconfigured remote adapter will cause compose failures that require manual recovery.
        return
            assetToStargateContract[asset] != address(0) &&
            _peerAdapter(destinationChainId) != address(0);
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
        address receivedAsset = _validateStargatePool(_from);

        // ---------------------------------------------------------------
        // 1. Taxi header must be present
        // ---------------------------------------------------------------
        if (!SummerTaxiCodec.isTaxi(_message)) revert InvalidMessage();

        // Decode taxi message (includes srcSender & compose payload)
        (
            ,
            ,
            uint amountSD,
            address srcSender,
            bytes memory composeMsg
        ) = SummerTaxiCodec.decodeTaxi(_message);

        // ---------------------------------------------------------------
        // 2. Verify peer adapter relationship
        // ---------------------------------------------------------------
        BridgeTypes.RelayedTransferParams
            memory atm = _decodeRelayedTransferParams(composeMsg);

        _assertTrustedSource(srcSender, uint16(atm.sourceChainId));
        _assertReceivedAmount(amountSD, atm.amount);
        // ---------------------------------------------------------------
        // 3. Continue normal handling (the SD amount from the Taxi header is
        // informational; the real LD amount lives inside the composeMsg)
        // ---------------------------------------------------------------

        IERC20(receivedAsset).safeTransfer(bridgeRouter(), atm.amount);
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            composeMsg
        );
    }

    /**
     * @dev Validates that a contract is a legitimate registered Stargate V2 pool
     * @param _from Address of the contract to validate
     * @return assetAddress The ERC20 token handled by this Stargate pool
     * @dev Reverts with Untrusted if validation fails
     */
    function _validateStargatePool(
        address _from
    ) internal view returns (address assetAddress) {
        assetAddress = stargateContractToAsset[_from];
        if (assetAddress == address(0))
            revert Untrusted("Stargate pool", _from, address(0));
    }

    /**
     * @notice Get the LayerZero Endpoint ID for a given chain
     */
    function getEndpointId(uint16 chainId) external view returns (uint32) {
        return chainToExternalId[chainId];
    }

    /**
     * @notice Manual recovery for edge cases
     * @dev When automated recovery isn't possible, governance can manually send assets
     * @param asset Token to recover
     * @param amount Amount to recover
     * @param recipient Where to send the tokens
     * @param operationId Operation ID to clear (optional)
     * @param tryReceiveCall Whether to attempt receiveOperation(BridgeTypes.OperationType.TRANSFER_ASSET,abi.encode( call
     * @param customMessage Custom message for receiveOperation(BridgeTypes.OperationType.TRANSFER_ASSET,abi.encode( (if tryReceiveCall is true)
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
                ICrossChainReceiver(recipient).receiveOperation(
                    BridgeTypes.OperationType.TRANSFER_ASSET,
                    abi.encode(
                        BridgeTypes.RelayedTransferParams({
                            operationId: operationId,
                            originator: address(this),
                            sourceChainId: uint16(block.chainid),
                            recipient: recipient,
                            asset: asset,
                            amount: amount,
                            message: customMessage
                        })
                    )
                )
            {
                // Success - call completed
            } catch (bytes memory reason) {
                // Log failure but continue - tokens were already sent
                emit ComposeCallFailed(
                    operationId,
                    recipient,
                    reason,
                    uint16(block.chainid)
                );
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
