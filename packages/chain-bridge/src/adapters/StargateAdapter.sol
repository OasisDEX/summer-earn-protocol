// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {IStargateRouter} from "../interfaces/IStargateRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStargateReceiver} from "../interfaces/IStargateReceiver.sol";

/**
 * @title StargateAdapter
 * @notice Adapter for Stargate Protocol to facilitate cross-chain asset transfers
 * @dev Implements IBridgeAdapter interface and connects to Stargate Router for efficient liquidity bridging
 */
contract StargateAdapter is Ownable, IBridgeAdapter, IStargateReceiver {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeRouter that manages this adapter
    address public immutable bridgeRouter;

    /// @notice Address of the Stargate Router contract
    address public immutable stargateRouter;

    /// @notice Mapping of supported chains to their Stargate chain IDs
    mapping(uint16 chainId => uint16 stargateChainId)
        public chainToStargateChainId;

    /// @notice Mapping of chains to supported assets and their pool IDs
    mapping(uint16 chainId => mapping(address asset => uint256 poolId))
        public chainAssetToPoolId;

    /// @notice List of supported chains
    uint16[] public supportedChains;

    /// @notice Mapping of chains to supported asset addresses
    mapping(uint16 chainId => address[] assets) public chainToSupportedAssets;

    /// @notice Minimum gas limit for destination transaction execution
    uint256 public minDstGasForCall = 300000;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a chain support is added
    event ChainSupported(uint16 chainId, uint16 stargateChainId);

    /// @notice Emitted when an asset support is added
    event AssetSupported(uint16 chainId, address asset, uint256 poolId);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the StargateAdapter
     * @param _stargateRouter Address of the Stargate Router contract
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _owner Address of the contract owner
     */
    constructor(
        address _stargateRouter,
        address _bridgeRouter,
        address _owner
    ) Ownable(_owner) {
        if (_stargateRouter == address(0) || _bridgeRouter == address(0))
            revert InvalidParams();

        stargateRouter = _stargateRouter;
        bridgeRouter = _bridgeRouter;
    }

    /*//////////////////////////////////////////////////////////////
                          GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the minimum destination gas for calls
     * @param _minDstGasForCall New minimum gas value
     * @dev Can only be called by the contract owner
     */
    function setMinDstGasForCall(uint256 _minDstGasForCall) external onlyOwner {
        minDstGasForCall = _minDstGasForCall;
    }

    /**
     * @notice Adds support for a new chain
     * @param chainId Chain ID in our system
     * @param stargateChainId Corresponding Stargate chain ID
     * @dev Can only be called by the contract owner
     */
    function addSupportedChain(
        uint16 chainId,
        uint16 stargateChainId
    ) external onlyOwner {
        if (chainToStargateChainId[chainId] != 0) revert InvalidParams();

        chainToStargateChainId[chainId] = stargateChainId;
        supportedChains.push(chainId);

        emit ChainSupported(chainId, stargateChainId);
    }

    /**
     * @notice Adds support for an asset on a specific chain
     * @param chainId Chain ID in our system
     * @param asset Address of the asset to support
     * @param poolId Stargate pool ID for the asset
     * @dev Can only be called by the contract owner
     */
    function addSupportedAsset(
        uint16 chainId,
        address asset,
        uint256 poolId
    ) external onlyOwner {
        if (chainToStargateChainId[chainId] == 0) revert UnsupportedChain();
        if (asset == address(0)) revert InvalidParams();

        // Add pool ID mapping
        chainAssetToPoolId[chainId][asset] = poolId;

        // Add to the list of supported assets for this chain
        address[] storage assets = chainToSupportedAssets[chainId];

        // Check if asset is already added
        bool exists = false;
        for (uint i = 0; i < assets.length; i++) {
            if (assets[i] == asset) {
                exists = true;
                break;
            }
        }

        if (!exists) {
            assets.push(asset);
        }

        emit AssetSupported(chainId, asset, poolId);
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable override returns (bytes32 transferId) {
        // Only the BridgeRouter should call this function
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Check if chain and asset are supported
        if (!supportsChain(destinationChainId)) revert UnsupportedChain();
        if (!supportsAsset(destinationChainId, asset))
            revert UnsupportedAsset();

        // Generate a unique transfer ID and mark as pending
        transferId = _generateTransferId(
            destinationChainId,
            asset,
            amount,
            recipient
        );

        // Transfer tokens from sender to this contract first
        IERC20(asset).safeTransferFrom(originator, address(this), amount);

        // Approve Stargate Router to spend the tokens
        IERC20(asset).approve(stargateRouter, 0);
        IERC20(asset).approve(stargateRouter, amount);

        // Estimate the fee
        (uint256 fee, ) = estimateFee(
            destinationChainId,
            asset,
            amount,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Verify sufficient fee was provided
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);

        // Execute the Stargate swap
        _executeStargateSwap(
            destinationChainId,
            asset,
            recipient,
            amount,
            originator,
            transferId,
            adapterParams
        );

        return transferId;
    }

    /**
     * @dev Internal function to generate a transfer ID
     */
    function _generateTransferId(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    ) internal returns (bytes32 operationId) {
        // Generate a unique transfer ID
        operationId = keccak256(
            abi.encode(
                block.chainid,
                destinationChainId,
                asset,
                amount,
                recipient,
                block.timestamp
            )
        );

        // Update status in bridge router instead
        IBridgeRouter(bridgeRouter).updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.PENDING
        );

        return operationId;
    }

    /**
     * @dev Struct to bundle all Stargate swap parameters to reduce stack depth
     */
    struct StargateSwapParams {
        uint16 dstChainId;
        uint256 srcPoolId;
        uint256 dstPoolId;
        bytes toAddress;
        bytes payload;
        uint256 amount;
        address refundAddress;
        // Adding these to reduce parameters in _executeSwap
        address asset;
        bytes32 operationId;
        uint16 originalChainId;
        address recipient;
        IStargateRouter.lzTxObj lzTxParams;
    }

    /**
     * @dev Internal function to execute the Stargate swap
     */
    function _executeStargateSwap(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        bytes32 operationId,
        BridgeTypes.AdapterParams calldata adapterParams
    ) internal {
        // Prepare all swap parameters in a struct to reduce stack variables
        StargateSwapParams memory params;

        // Populate basic swap parameters
        params.dstChainId = chainToStargateChainId[destinationChainId];
        params.srcPoolId = chainAssetToPoolId[uint16(block.chainid)][asset];
        params.dstPoolId = chainAssetToPoolId[destinationChainId][asset];
        params.toAddress = abi.encodePacked(recipient);
        params.payload = abi.encode(operationId);
        params.amount = amount;
        params.refundAddress = originator;

        // Include additional parameters needed for events and error handling
        params.asset = asset;
        params.operationId = operationId;
        params.originalChainId = destinationChainId;
        params.recipient = recipient;

        // Prepare Stargate lzTxObj
        params.lzTxParams = IStargateRouter.lzTxObj({
            dstGasForCall: adapterParams.gasLimit > 0
                ? adapterParams.gasLimit
                : minDstGasForCall,
            dstNativeAmount: adapterParams.msgValue,
            dstNativeAddr: adapterParams.options
        });

        // Execute the swap through Stargate Router
        _executeSwap(params);
    }

    /**
     * @dev Executes the Stargate swap with prepared parameters
     */
    function _executeSwap(StargateSwapParams memory params) internal {
        try
            IStargateRouter(stargateRouter).swap{value: msg.value}(
                params.dstChainId,
                params.srcPoolId,
                params.dstPoolId,
                payable(params.refundAddress),
                params.amount,
                0, // min amount - could use slippage from adapterParams
                params.lzTxParams,
                params.toAddress,
                params.payload
            )
        {
            // Emit TransferInitiated event
            emit TransferInitiated(
                params.operationId,
                params.originalChainId,
                params.asset,
                params.amount,
                params.recipient
            );
        } catch {
            // Reset approval
            IERC20(params.asset).approve(stargateRouter, 0);

            // Refund tokens to originator
            IERC20(params.asset).safeTransfer(
                params.refundAddress,
                params.amount
            );

            // Update transfer status to failed through bridge router
            IBridgeRouter(bridgeRouter).updateOperationStatus(
                params.operationId,
                BridgeTypes.OperationStatus.FAILED
            );

            revert TransferFailed();
        }
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256,
        BridgeTypes.AdapterParams calldata adapterParams,
        BridgeTypes.OperationType
    ) public view returns (uint256 nativeFee, uint256 tokenFee) {
        // Check if chain and asset are supported
        if (!supportsChain(destinationChainId)) revert UnsupportedChain();
        if (!supportsAsset(destinationChainId, asset))
            revert UnsupportedAsset();

        // Get Stargate chain ID
        uint16 dstChainId = chainToStargateChainId[destinationChainId];

        // Prepare the recipient address as bytes - using a dummy address for estimation
        bytes memory toAddress = abi.encodePacked(address(0xdead));

        // Dummy payload for fee estimation
        bytes memory payload = abi.encode(bytes32(0));

        // Prepare Stargate lzTxObj
        IStargateRouter.lzTxObj memory lzTxParams = IStargateRouter.lzTxObj({
            dstGasForCall: adapterParams.gasLimit > 0
                ? adapterParams.gasLimit
                : minDstGasForCall,
            dstNativeAmount: adapterParams.msgValue,
            dstNativeAddr: adapterParams.options
        });

        // Quote the fee from Stargate Router
        (uint256 fee, ) = IStargateRouter(stargateRouter).quoteLayerZeroFee(
            dstChainId,
            1, // swap function type
            toAddress,
            payload,
            lzTxParams
        );

        return (fee, 0); // Stargate uses only native fees
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
    function getSupportedAssets(
        uint16 chainId
    ) external view override returns (address[] memory) {
        if (!supportsChain(chainId)) revert UnsupportedChain();
        return chainToSupportedAssets[chainId];
    }

    /// @inheritdoc IBridgeAdapter
    function supportsChain(uint16 chainId) public view override returns (bool) {
        return chainToStargateChainId[chainId] != 0;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsAsset(
        uint16 chainId,
        address asset
    ) public view override returns (bool) {
        if (!supportsChain(chainId)) {
            return false;
        }

        return chainAssetToPoolId[chainId][asset] != 0;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsAssetTransfer() external pure returns (bool) {
        return true;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsMessaging() external pure returns (bool) {
        return false;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsStateRead() external pure returns (bool) {
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                      RECEIVE ADAPTER IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stargate callback function - called on the destination chain
     * @dev Implements the Stargate receiver interface to handle incoming cross-chain transfers
     * @param _chainId Source chain ID in Stargate format
     * @param _srcAddress Source address as bytes
     * @param // _nonce Stargate nonce
     * @param _token Address of the token being transferred
     * @param _amount Amount of tokens received
     * @param _payload ABI encoded payload sent from source chain (contains transferId)
     */
    function sgReceive(
        uint16 _chainId,
        bytes memory _srcAddress,
        uint256,
        address _token,
        uint256 _amount,
        bytes memory _payload
    ) external override {
        // Verify that the sender is the Stargate Router
        if (msg.sender != stargateRouter) revert Unauthorized();

        // Decode the transfer ID from the payload
        bytes32 transferId = abi.decode(_payload, (bytes32));

        // Convert _srcAddress to an address (this would be the recipient encoded from the source chain)
        address recipient = abi.decode(_srcAddress, (address));

        // Forward the tokens to the recipient (likely CrossChainArkProxy)
        IERC20(_token).safeTransfer(recipient, _amount);

        // Notify the BridgeRouter about the completed transfer
        IBridgeRouter(bridgeRouter).notifyMessageReceived(
            transferId,
            _token,
            _amount,
            recipient,
            _chainId
        );

        // Emit event for the received transfer
        emit TransferReceived(transferId, _token, _amount, recipient);
    }

    /*//////////////////////////////////////////////////////////////
                      UNSUPPORTED OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISendAdapter
    function readState(
        uint16,
        uint16,
        address,
        bytes4,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert OperationNotSupported();
    }

    /// @inheritdoc ISendAdapter
    function sendMessage(
        uint16,
        address,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert OperationNotSupported();
    }
}
