// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseBridgeAdapter} from "../base/BaseBridgeAdapter.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {MessagingFee, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IStargateV2} from "../interfaces/IStargateV2.sol";
import {BpsUtils} from "../helpers/BpsUtils.sol";
import {LayerZeroComposeHelper} from "../helpers/LayerZeroComposeHelper.sol";

/**
 * @title StargateAdapter
 * @notice Adapter for Stargate V2 Protocol - all V2 contracts are OFT-enabled
 * @dev Implements IAssetAdapter and IBridgeAdapter interfaces and connects to Stargate V2 for efficient cross-chain transfers
 */
contract StargateAdapter is
    IAssetAdapter,
    IBridgeAdapter,
    ILayerZeroComposer,
    BaseBridgeAdapter
{
    using SafeERC20 for IERC20;
    using AddressCast for address;
    using AddressCast for bytes32;
    using OptionsBuilder for bytes;
    using Address for address payable;

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

    /// @notice Emitted when slippage tolerance is updated
    event SlippageToleranceUpdated(uint256 newSlippageBps);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when refunding excess native fee to `refundAddress` fails
    error RefundFailed(address recipient, uint256 amount);

    /// @notice Thrown when LayerZero endpoint address is invalid
    error InvalidLzEndpoint();

    /// @notice Thrown when slippage tolerance is outside valid range
    error InvalidSlippageTolerance(uint256 provided);

    /// @notice Thrown when asset address is invalid
    error InvalidAssetAddress();

    /// @notice Thrown when Stargate contract address is invalid
    error InvalidStargateContract();

    /// @notice Thrown when Stargate contract type is invalid
    error InvalidStargateType();

    /// @notice Thrown when Stargate pool token doesn't match expected asset
    error InvalidStargatePoolToken(address expected, address actual);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the StargateAdapter
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _accessManager Address of the AccessManager contract
     * @param _lzEndpoint LayerZero endpoint for compose functionality
     */
    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint
    ) BaseBridgeAdapter(_crossChainRegistry, _accessManager) {
        if (_lzEndpoint == address(0)) revert InvalidLzEndpoint();

        LZ_ENDPOINT = _lzEndpoint;
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the slippage tolerance for fallback minimum amount calculation
     * @param _slippageBps New slippage tolerance in basis points (e.g., 50 = 0.5%)
     */
    function setSlippageTolerance(uint256 _slippageBps) external onlyGovernor {
        if (
            _slippageBps < MIN_SLIPPAGE_BPS || _slippageBps > MAX_SLIPPAGE_BPS
        ) {
            revert InvalidSlippageTolerance(_slippageBps);
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
        if (asset == address(0)) revert InvalidAssetAddress();
        if (stargateContract == address(0)) revert InvalidStargateContract();

        // Verify this is a valid Stargate V2 contract (only for current chain)
        try IStargateV2(stargateContract).stargateType() returns (
            IStargateV2.StargateType stargateTypeValue
        ) {
            if (stargateTypeValue != IStargateV2.StargateType.Pool) {
                revert InvalidStargateType();
            }
        } catch {
            revert InvalidStargateType();
        }

        address stargatePoolToken = IStargateV2(stargateContract).token();
        if (stargatePoolToken != asset) {
            revert InvalidStargatePoolToken(asset, stargatePoolToken);
        }

        assetToStargateContract[asset] = stargateContract;
        stargateContractToAsset[stargateContract] = asset;

        emit AssetSupported(uint16(block.chainid), asset, stargateContract);
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

    /// @inheritdoc IBridgeAdapter
    function estimateTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        onlyTrustedDestination(params.destinationChainId)
        returns (uint256 nativeFee, uint256 tokenFee)
    {
        if (!this.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)) {
            revert OperationNotSupported();
        }

        // Get the source chain Stargate contract
        address stargateContract = assetToStargateContract[params.asset];

        // Check if asset is supported on current chain
        if (stargateContract == address(0)) {
            revert UnsupportedAsset();
        }

        // Use dummy operationId for estimation
        bytes32 dummyOperationId = bytes32(uint256(uint160(params.target)));

        // Prepare validated SendParam with slippage protection
        (SendParam memory sendParam, ) = _prepareSendParamForTransfer(
            params,
            dummyOperationId,
            BridgeTypes.BridgeOptions({
                specifiedAdapter: options.specifiedAdapter,
                gasLimit: options.gasLimit,
                calldataSize: options.calldataSize,
                msgValue: options.msgValue,
                options: options.options
            }),
            stargateContract
        );

        MessagingFee memory msgFee = IStargateV2(stargateContract).quoteSend(
            sendParam,
            false
        );
        return (msgFee.nativeFee, 0);
    }

    /// @inheritdoc IBridgeAdapter
    function estimateSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external pure returns (uint256, uint256) {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure override returns (bool) {
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
            _hasTrustedDestination(destinationChainId);
    }

    /*//////////////////////////////////////////////////////////////
                        LAYERZERO COMPOSE HANDLER
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
        // Decode OFT compose payload using official codec
        // ---------------------------------------------------------------
        (
            uint32 srcEid,
            uint256 amountLD,
            address srcSender,
            bytes memory composeMsg
        ) = LayerZeroComposeHelper.decodeOFTCompose(_message);

        // ---------------------------------------------------------------
        // 2. Verify peer adapter relationship
        // ---------------------------------------------------------------
        BridgeTypes.RelayedTransferParams
            memory atm = _decodeRelayedTransferParams(composeMsg);
        _assertTrustedSource(srcSender, uint16(atm.sourceChainId));

        // Use the minted amount from OFT compose header as authoritative
        atm.amount = amountLD;
        // Ensure the LayerZero srcEid maps to the same chain as encoded in the payload
        uint16 chainFromEid = externalIdToChainId[srcEid];
        _validateSourceChainId(atm.sourceChainId, chainFromEid);

        // Overwrite the asset with the local token address resolved from the Stargate pool
        // The asset encoded on the source chain may not match the target-chain address
        atm.asset = receivedAsset;

        // ---------------------------------------------------------------
        // 3. Continue normal handling (the OFT amount from the compose header is
        // authoritative; the real LD amount is provided by the OFT protocol)
        // ---------------------------------------------------------------

        IERC20(receivedAsset).safeTransfer(bridgeRouter(), atm.amount);
        IBridgeRouter(bridgeRouter()).deliver(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(atm)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

        // Prepare validated SendParam with slippage protection
        (SendParam memory sendParam, ) = _prepareSendParamForTransfer(
            params,
            operationId,
            options,
            stargateContract
        );

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
            (bool success, ) = payable(params.refundAddress).call{
                value: refundAmount
            }("");
            if (!success) {
                revert RefundFailed(params.refundAddress, refundAmount);
            }
        }
    }

    /**
     * @dev Helper function to create compose options with the given gas limit
     * @param gas Gas limit for the compose execution
     * @param composeMsg The compose message to check for length
     * @return Encoded options for LayerZero compose functionality
     */
    function _composeOptions(
        uint128 gas,
        bytes memory composeMsg
    ) internal pure returns (bytes memory) {
        // Only add compose options when compose message is present
        if (composeMsg.length > 0) {
            return
                OptionsBuilder.newOptions().addExecutorLzComposeOption(
                    0,
                    gas,
                    0
                );
        }
        return bytes("");
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
        // Use transport mode for consistency
        // Always use taxi mode for cross-chain asset transfers
        bytes memory oftCmd = bytes("");

        // Add compose options (logic is now inside _composeOptions)
        bytes memory extraOptions = _composeOptions(
            uint128(_requireGasLimit(options.gasLimit)),
            composeMsg
        );

        return
            SendParam({
                dstEid: _externalIdForChain(destinationChainId),
                to: destinationAdapter.toBytes32(),
                amountLD: amount,
                minAmountLD: amount,
                extraOptions: extraOptions,
                composeMsg: composeMsg,
                oftCmd: oftCmd
            });
    }

    /**
     * @dev Prepares a validated SendParam with slippage protection (shared by execute and estimate)
     * @param params Transfer parameters
     * @param operationId The operation ID for this transfer
     * @param options Bridge options
     * @param stargateContract The Stargate V2 contract for quotes
     * @return sendParam Validated SendParam ready for execution
     * @return oftReceipt Quote receipt with slippage-validated amounts
     */
    function _prepareSendParamForTransfer(
        BridgeTypes.ExecuteTransferParams memory params,
        bytes32 operationId,
        BridgeTypes.BridgeOptions memory options,
        address stargateContract
    )
        internal
        view
        returns (SendParam memory sendParam, OFTReceipt memory oftReceipt)
    {
        // Resolve destination adapter via registry
        address destinationAdapter = _getAdapterPeer(params.destinationChainId);

        // Build SendParam - Stargate will wrap this with OFTComposeMsgCodec internally
        sendParam = _buildSendParam(
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

        // Get quote from Stargate
        (, , oftReceipt) = IStargateV2(stargateContract).quoteOFT(sendParam);

        // Calculate minimum slippage threshold using BPS utility
        uint256 minExpectedAmount = BpsUtils.applyBpsDiscount(
            params.amount,
            slippageToleranceBps
        );

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
     * @dev Determines transport mode based on adapter params
     */
    function _getTransportMode(
        BridgeTypes.BridgeOptions calldata,
        bool
    ) internal pure returns (bytes memory) {
        // Always use taxi mode for cross-chain asset transfers
        // This aligns with the pattern shown in Stargate V2 examples
        // Taxi mode is more reliable and required for compose functionality
        return bytes(""); // Returns ""
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
}
