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

// Stargate V2 interfaces - based on LayerZero V2 OFT standard
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt, OFTLimit, OFTFeeDetail} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
// Add LayerZero composability imports
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";

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
contract StargateAdapter is Ownable, IBridgeAdapter, IOAppComposer {
    using SafeERC20 for IERC20;
    using AddressCast for address;
    using OptionsBuilder for bytes;

    /// @notice Error for unsupported asset
    error UnsupportedAsset();

    /// @notice Transfer parameters struct to avoid stack too deep
    struct TransferParams {
        address stargateContract;
        uint16 destinationChainId;
        address asset;
        address recipient;
        uint256 amount;
        address originator;
        bytes32 operationId;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeRouter that manages this adapter
    address public bridgeRouter;

    /// @notice LayerZero endpoint for compose functionality
    address public immutable lzEndpoint;

    /// @notice Mapping of assets to their Stargate contracts on THIS chain only
    mapping(address asset => address stargateContract)
        public assetToStargateContract;

    /// @notice Mapping of destination chains to their StargateAdapter addresses
    mapping(uint16 chainId => address adapterAddress) public chainToAdapter;

    /// @notice List of supported chains
    uint16[] public supportedChains;

    /// @notice Minimum gas limit for destination transaction execution
    uint256 public minDstGasForCall = 300000;

    /// @notice Default transport mode (true = taxi, false = bus)
    bool public defaultUseTaxi = false;

    /// @notice Gas limit for compose execution on destination
    uint256 public composeGasLimit = 200000;

    /// @notice Minimum gas limit for compose execution
    uint256 public constant MIN_COMPOSE_GAS = 100000;

    /// @notice Maximum gas limit for compose execution
    uint256 public constant MAX_COMPOSE_GAS = 500000;

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
     * @notice Sets the minimum destination gas for calls
     * @param _minDstGasForCall New minimum gas value
     */
    function setMinDstGasForCall(uint256 _minDstGasForCall) external onlyOwner {
        minDstGasForCall = _minDstGasForCall;
    }

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
        if (chainToAdapter[chainId] != address(0)) revert InvalidParams();

        chainToAdapter[chainId] = adapterAddress;
        supportedChains.push(chainId);

        emit ChainSupported(chainId, endpointId);
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
        assetToStargateContract[asset] = stargateContract;
        emit AssetSupported(
            supportedChains[supportedChains.length - 1],
            asset,
            stargateContract
        );
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
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable override {
        // Only the BridgeRouter should call this function
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Check if chain and asset are supported
        if (!supportsChain(destinationChainId)) revert UnsupportedChain();
        if (!isAssetSupported(destinationChainId, asset))
            revert UnsupportedAsset();

        // Get the source chain Stargate contract
        address stargateContract = assetToStargateContract[asset];
        if (stargateContract == address(0)) revert UnsupportedAsset();

        // Get destination adapter (same for all assets on that chain)
        address destinationAdapter = chainToAdapter[destinationChainId];
        if (destinationAdapter == address(0)) revert UnsupportedChain();

        // Transfer tokens from BridgeRouter to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Approve Stargate contract to spend the tokens
        IERC20(asset).approve(stargateContract, 0);
        IERC20(asset).approve(stargateContract, amount);

        // Execute the Stargate V2 transfer (all V2 contracts are OFT-enabled)
        TransferParams memory params = TransferParams({
            stargateContract: stargateContract,
            destinationChainId: destinationChainId,
            asset: asset,
            recipient: recipient,
            amount: amount,
            originator: originator,
            operationId: operationId
        });

        _executeStargateTransfer(params, adapterParams);

        IBridgeRouter(bridgeRouter).updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.SENT
        );
    }

    /**
     * @dev Execute Stargate V2 transfer - all V2 contracts use the same OFT interface
     */
    function _executeStargateTransfer(
        TransferParams memory params,
        BridgeTypes.AdapterParams calldata adapterParams
    ) internal {
        // Create and execute the transfer
        _executeSendToken(params, params.stargateContract, adapterParams);
    }

    /**
     * @dev Execute the actual sendToken call
     */
    function _executeSendToken(
        TransferParams memory params,
        address destinationAdapter,
        BridgeTypes.AdapterParams calldata adapterParams
    ) internal {
        IStargate stargate = IStargate(params.stargateContract);

        // Create compose message
        bytes memory composeMsg = abi.encode(
            params.recipient,
            params.asset,
            params.amount,
            uint16(block.chainid),
            params.operationId,
            params.originator
        );

        // Build SendParam
        SendParam memory sendParam = _buildSendParam(
            params.destinationChainId,
            destinationAdapter,
            params.amount,
            composeMsg,
            adapterParams
        );

        // Update minAmountLD based on quote
        _updateMinAmount(stargate, sendParam, params.amount);

        // Execute transfer
        _performTransfer(stargate, sendParam, params);
    }

    /**
     * @dev Build SendParam struct
     */
    function _buildSendParam(
        uint16 destinationChainId,
        address destinationAdapter,
        uint256 amount,
        bytes memory composeMsg,
        BridgeTypes.AdapterParams calldata adapterParams
    ) internal view returns (SendParam memory) {
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, uint128(composeGasLimit), 0);

        return
            SendParam({
                dstEid: chainToAdapter[destinationChainId],
                to: destinationAdapter.toBytes32(),
                amountLD: amount,
                minAmountLD: amount,
                extraOptions: extraOptions,
                composeMsg: composeMsg,
                oftCmd: _getTransportMode(adapterParams)
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
        TransferParams memory params
    ) internal {
        MessagingFee memory messagingFee = stargate.quoteSend(sendParam, false);

        if (msg.value < messagingFee.nativeFee) {
            revert InsufficientFee(messagingFee.nativeFee, msg.value);
        }

        try
            stargate.sendToken{value: msg.value}(
                sendParam,
                messagingFee,
                params.originator
            )
        {
            emit TransferInitiated(
                params.operationId,
                params.destinationChainId,
                params.asset,
                params.amount,
                params.recipient
            );
        } catch {
            _handleTransferFailure(
                params.stargateContract,
                params.asset,
                params.amount,
                params.originator,
                params.operationId
            );
        }
    }

    /**
     * @dev Handle transfer failure cleanup
     */
    function _handleTransferFailure(
        address stargateContract,
        address asset,
        uint256 amount,
        address originator,
        bytes32 operationId
    ) internal {
        // Reset approval
        IERC20(asset).approve(stargateContract, 0);

        // Refund tokens to originator
        IERC20(asset).safeTransfer(originator, amount);

        // Update transfer status to failed
        IBridgeRouter(bridgeRouter).updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.FAILED
        );

        revert TransferFailed();
    }

    /**
     * @dev Determines transport mode based on adapter params
     */
    function _getTransportMode(
        BridgeTypes.AdapterParams calldata adapterParams
    ) internal view returns (bytes memory) {
        // Check if specific mode is requested in options
        if (adapterParams.options.length > 0) {
            // Parse options to determine if taxi mode is requested
            // For now, default to adapter setting
        }

        return defaultUseTaxi ? OftCmdHelper.taxi() : OftCmdHelper.bus();
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

        // Check if asset is supported
        if (
            operationType == BridgeTypes.OperationType.TRANSFER_ASSET &&
            !isAssetSupported(destinationChainId, asset)
        ) {
            revert UnsupportedAsset();
        }

        // Get the source chain Stargate contract
        address stargateContract = assetToStargateContract[asset];
        if (stargateContract == address(0)) revert UnsupportedAsset();

        // Always include compose options in fee estimation
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, 200000, 0);

        // Prepare SendParam for quote
        SendParam memory sendParam = SendParam({
            dstEid: chainToAdapter[destinationChainId],
            to: address(0xdead).toBytes32(),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: extraOptions,
            composeMsg: abi.encode(
                uint16(block.chainid),
                bytes32(0),
                address(0)
            ), // Dummy compose message
            oftCmd: _getTransportMode(adapterParams)
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
        return assetToStargateContract[asset] != address(0);
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
     * @notice Get the Stargate contract address for a given asset
     */
    function getStargateContract(
        address asset
    ) external view returns (address) {
        return assetToStargateContract[asset];
    }

    /**
     * @notice Handles composed messages from LayerZero after Stargate token delivery
     * @dev Called by LayerZero endpoint after tokens are delivered to FleetProxy
     * @param // _oApp The originating OApp (should be source StargateAdapter)
     * @param // _guid Message GUID
     * @param _message Encoded compose message with operation details
     * @param // _executor Executor address
     * @param // _extraData Additional executor data
     */
    function lzCompose(
        address /*_oApp*/,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) external payable override {
        // Verify caller is LayerZero endpoint
        if (msg.sender != lzEndpoint) {
            revert Unauthorized();
        }

        // Decode the compose message from source adapter
        (
            address fleetProxy,
            address asset,
            uint256 amount,
            uint16 sourceChainId,
            bytes32 operationId,
            address originator
        ) = abi.decode(
                _message,
                (address, address, uint256, uint16, bytes32, address)
            );

        // Transfer tokens from adapter to FleetProxy
        // The tokens were delivered to this adapter by Stargate
        IERC20(asset).safeTransfer(fleetProxy, amount);

        // Call FleetProxy to handle the received assets
        ICrossChainAssetReceiver(fleetProxy).receiveMessageWithAssets(
            asset,
            amount,
            abi.encode(operationId, originator), // Pass operation details as message
            sourceChainId
        );

        emit ComposedAssetHandled(
            operationId,
            fleetProxy,
            asset,
            amount,
            sourceChainId
        );
    }
}
