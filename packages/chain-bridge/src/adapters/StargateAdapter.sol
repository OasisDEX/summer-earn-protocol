// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Stargate V2 interfaces - based on LayerZero V2 OFT standard
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

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
        returns (uint256 limit, uint256 oftLimit, OFTReceipt memory oftReceipt);

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
 * @notice Adapter for Stargate V2 Protocol supporting both Pool and Hydra (OFT) assets
 * @dev Implements IBridgeAdapter interface and connects to Stargate V2 for efficient cross-chain transfers
 */
contract StargateAdapter is Ownable, IBridgeAdapter {
    using SafeERC20 for IERC20;

    /// @notice Error for unsupported asset
    error UnsupportedAsset();
    /// @notice Error for unsupported stargate type
    error UnsupportedStargateType();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeRouter that manages this adapter
    address public bridgeRouter;

    /// @notice Mapping of supported chains to their LayerZero Endpoint IDs
    mapping(uint16 chainId => uint32 endpointId) public chainToEndpointId;

    /// @notice Mapping of chains and assets to their Stargate V2 contract addresses
    mapping(uint16 chainId => mapping(address asset => address stargateContract))
        public chainAssetToStargate;

    /// @notice List of supported chains
    uint16[] public supportedChains;

    /// @notice Mapping of chains to supported asset addresses
    mapping(uint16 chainId => address[] assets) public chainToSupportedAssets;

    /// @notice Minimum gas limit for destination transaction execution
    uint256 public minDstGasForCall = 300000;

    /// @notice Default transport mode (true = taxi, false = bus)
    bool public defaultUseTaxi = false;

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

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the StargateV2Adapter
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _owner Address of the contract owner
     */
    constructor(address _bridgeRouter, address _owner) Ownable(_owner) {
        if (_bridgeRouter == address(0)) revert InvalidParams();

        bridgeRouter = _bridgeRouter;
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
     * @notice Adds support for a new chain
     * @param chainId Chain ID in our system
     * @param endpointId Corresponding LayerZero Endpoint ID
     */
    function addSupportedChain(
        uint16 chainId,
        uint32 endpointId
    ) external onlyOwner {
        if (chainToEndpointId[chainId] != 0) revert InvalidParams();

        chainToEndpointId[chainId] = endpointId;
        supportedChains.push(chainId);

        emit ChainSupported(chainId, endpointId);
    }

    /**
     * @notice Adds support for an asset on a specific chain
     * @param chainId Chain ID in our system
     * @param asset Address of the asset to support
     * @param stargateContract Address of the Stargate V2 contract for this asset
     */
    function addSupportedAsset(
        uint16 chainId,
        address asset,
        address stargateContract
    ) external onlyOwner {
        if (chainToEndpointId[chainId] == 0) revert UnsupportedChain();
        if (asset == address(0) || stargateContract == address(0))
            revert InvalidParams();

        // Verify this is a valid Stargate contract
        try IStargate(stargateContract).stargateType() returns (
            IStargate.StargateType
        ) {
            // Valid Stargate contract
        } catch {
            revert InvalidParams();
        }

        // Add Stargate contract mapping
        chainAssetToStargate[chainId][asset] = stargateContract;

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

        emit AssetSupported(chainId, asset, stargateContract);
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
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable override returns (bytes32 operationId) {
        // Only the BridgeRouter should call this function
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Check if chain and asset are supported
        if (!supportsChain(destinationChainId)) revert UnsupportedChain();
        if (!isAssetSupported(destinationChainId, asset))
            revert UnsupportedAsset();

        // Get the source chain Stargate contract
        address stargateContract = chainAssetToStargate[uint16(block.chainid)][
            asset
        ];
        if (stargateContract == address(0)) revert UnsupportedAsset();

        // Generate a unique transfer ID
        operationId = _generateTransferId(
            destinationChainId,
            asset,
            amount,
            recipient
        );

        // Transfer tokens from BridgeRouter to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Approve Stargate contract to spend the tokens
        IERC20(asset).approve(stargateContract, 0);
        IERC20(asset).approve(stargateContract, amount);

        // Execute the Stargate V2 transfer
        _executeStargateV2Transfer(
            stargateContract,
            destinationChainId,
            asset,
            recipient,
            amount,
            originator,
            operationId,
            adapterParams
        );

        return operationId;
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
        operationId = keccak256(
            abi.encode(
                block.chainid,
                destinationChainId,
                asset,
                amount,
                recipient,
                block.timestamp,
                block.number
            )
        );

        IBridgeRouter(bridgeRouter).updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.SENT
        );

        return operationId;
    }

    /**
     * @dev Internal function to execute Stargate V2 transfer
     */
    function _executeStargateV2Transfer(
        address stargateContract,
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        bytes32 operationId,
        BridgeTypes.AdapterParams calldata adapterParams
    ) internal {
        IStargate stargate = IStargate(stargateContract);

        // Prepare SendParam
        SendParam memory sendParam = SendParam({
            dstEid: chainToEndpointId[destinationChainId],
            to: _addressToBytes32(recipient),
            amountLD: amount,
            minAmountLD: amount, // Will be updated after quote
            extraOptions: new bytes(0), // Can be customized for specific use cases
            composeMsg: new bytes(0), // No composability for basic transfers
            oftCmd: _getTransportMode(adapterParams) // Taxi or Bus mode
        });

        // Get quote to determine actual received amount
        try stargate.quoteOFT(sendParam) returns (
            uint256,
            uint256,
            OFTReceipt memory oftReceipt
        ) {
            sendParam.minAmountLD = oftReceipt.amountReceivedLD;
        } catch {
            // Fallback to original amount if quote fails
            sendParam.minAmountLD = (amount * 9950) / 10000; // 0.5% slippage
        }

        // Get messaging fee
        MessagingFee memory messagingFee = stargate.quoteSend(sendParam, false);

        // Verify sufficient fee was provided
        if (msg.value < messagingFee.nativeFee) {
            revert InsufficientFee(messagingFee.nativeFee, msg.value);
        }

        // Execute the transfer
        try
            stargate.sendToken{value: msg.value}(
                sendParam,
                messagingFee,
                originator // refund address
            )
        returns (
            MessagingReceipt memory,
            OFTReceipt memory,
            IStargate.Ticket memory
        ) {
            // Emit success event
            emit TransferInitiated(
                operationId,
                destinationChainId,
                asset,
                amount,
                recipient
            );
        } catch {
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
        address stargateContract = chainAssetToStargate[uint16(block.chainid)][
            asset
        ];
        if (stargateContract == address(0)) revert UnsupportedAsset();

        // Prepare SendParam for quote
        SendParam memory sendParam = SendParam({
            dstEid: chainToEndpointId[destinationChainId],
            to: _addressToBytes32(address(0xdead)), // Dummy recipient for estimation
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: new bytes(0),
            composeMsg: new bytes(0),
            oftCmd: _getTransportMode(adapterParams)
        });

        // Get messaging fee quote
        try IStargate(stargateContract).quoteSend(sendParam, false) returns (
            MessagingFee memory msgFee
        ) {
            return (msgFee.nativeFee, 0); // Stargate V2 uses only native fees
        } catch {
            // Fallback estimation
            return (0.01 ether, 0); // Conservative estimate
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
        return chainToEndpointId[chainId] != 0;
    }

    /**
     * @notice Get the list of supported assets for a specific chain
     * @param chainId Chain ID to get supported assets for
     * @return Array of addresses representing supported assets
     */
    function getSupportedAssets(
        uint16 chainId
    ) external view returns (address[] memory) {
        return chainToSupportedAssets[chainId];
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

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Helper function to check if an asset is supported on a specific chain
     */
    function isAssetSupported(
        uint16 chainId,
        address asset
    ) public view returns (bool) {
        return chainAssetToStargate[chainId][asset] != address(0);
    }

    /**
     * @dev Helper function to convert address to bytes32
     */
    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /**
     * @notice Get the Stargate contract address for a given chain and asset
     */
    function getStargateContract(
        uint16 chainId,
        address asset
    ) external view returns (address) {
        return chainAssetToStargate[chainId][asset];
    }

    /**
     * @notice Get the LayerZero endpoint ID for a given chain
     */
    function getEndpointId(uint16 chainId) external view returns (uint32) {
        return chainToEndpointId[chainId];
    }
}
