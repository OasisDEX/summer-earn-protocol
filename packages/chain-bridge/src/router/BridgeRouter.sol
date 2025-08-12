// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";

import {ICrossChainReceiver} from "../interfaces/ICrossChainReceiver.sol";
import {IInflightAssetTracking} from "../interfaces/IInflightAssetTracking.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";

/**
 * @title BridgeRouter
 * @notice Central router that coordinates cross-chain asset transfers and data queries
 * @dev Implements IBridgeRouter interface and manages multiple bridge adapters.
 *      Operations can only be initiated via the authorized executor or governance.
 */
contract BridgeRouter is
    IBridgeRouter,
    ProtocolAccessManaged,
    ReentrancyGuard,
    Nonces,
    CrossChainConfigManaged
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Set of registered adapters
    EnumerableSet.AddressSet private adapters;

    /// @notice Mapping of operation IDs to the adapter that processed them
    mapping(bytes32 operationId => address adapterAddress)
        public operationToAdapter;

    /// @notice Mapping to track read request originators
    mapping(bytes32 requestId => address originator)
        public readRequestToOriginator;

    /// @notice Pause state of the router
    bool public paused;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the BridgeRouter contract
     * @param accessManager Address of the ProtocolAccessManager contract
     * @param _registry Address of the CrossChainRegistry contract
     */
    constructor(
        address accessManager,
        address _registry
    ) ProtocolAccessManaged(accessManager) CrossChainConfigManaged(_registry) {}

    /*//////////////////////////////////////////////////////////////
                        MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier ensuring the caller (`msg.sender`) is a registered adapter.
     * Reverts with `UnknownAdapter` if the caller is not in the `adapters` set.
     */
    modifier onlyRegisteredAdapter() {
        if (!adapters.contains(msg.sender)) revert UnknownAdapter();
        _;
    }

    /**
     * @dev Modifier ensuring the contract is not paused.
     * Reverts with `Paused` if the contract is in the paused state.
     */
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                    ADAPTER PEER RELATIONSHIP CHECK
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Asserts that a peer mapping exists in the registry for `(sourceChainId, msg.sender)`.
     * @param sourceChainId The source chain ID from the cross-chain operation
     *
     * NOTE: This only verifies that governance has registered a peer relationship for the
     *       calling adapter on the given source chain. It does NOT authenticate the
     *       specific source adapter that originated the packet. Identity binding is enforced
     *       within adapters using bridge-native metadata (e.g. LayerZero Origin.sender, Taxi srcSender)
     *       via the registry's `isValidAdapterPeer` checks.
     */
    function _assertPeerMappingExistsForChain(
        uint16 sourceChainId
    ) internal view {
        // Will revert if (srcChainId, msg.sender) is NOT a registered pair
        CROSS_CHAIN_REGISTRY.getSourceForTarget(
            sourceChainId,
            uint16(block.chainid),
            msg.sender,
            CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
        );
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to validate transfer parameters
     * @param params Parameters to validate
     */
    function _validateTransferParams(
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal pure {
        if (
            params.amount == 0 ||
            params.target == address(0) ||
            params.originator == address(0) ||
            params.asset == address(0) ||
            params.refundAddress == address(0) ||
            params.destinationChainId == 0
        ) revert InvalidParams();
    }

    /**
     * @dev Internal function to validate read state parameters
     * @param params Parameters to validate
     */
    function _validateReadStateParams(
        BridgeTypes.ExecuteReadStateParams calldata params
    ) internal pure {
        if (
            params.originator == address(0) ||
            params.target == address(0) ||
            params.destinationChainId == 0 ||
            params.selector == bytes4(0) ||
            params.refundAddress == address(0)
        ) revert InvalidParams();
    }

    /**
     * @dev Internal function to validate send message parameters
     * @param params Parameters to validate
     */
    function _validateSendMessageParams(
        BridgeTypes.ExecuteSendMessageParams calldata params
    ) internal pure {
        if (
            params.target == address(0) ||
            params.originator == address(0) ||
            params.destinationChainId == 0 ||
            params.refundAddress == address(0) ||
            params.message.length == 0
        ) {
            revert InvalidParams();
        }
    }

    function _validateOriginator(address originator) internal view {
        if (originator != msg.sender) revert InvalidOriginator();
    }

    /**
     * @dev Internal function to validate if an adapter supports a specific operation type
     * @param adapter The adapter address to validate
     * @param operationType The type of operation to check support for
     */
    function _validateAdapterSupportsOperation(
        address adapter,
        BridgeTypes.OperationType operationType
    ) internal view {
        if (adapter == address(0)) revert NoSuitableAdapter();
        if (!IBridgeAdapter(adapter).supportsOperation(operationType)) {
            revert UnsupportedAdapterOperation();
        }
    }

    /**
     * @dev Internal function to validate provided fee against required fee
     * @param providedFee The fee provided with the transaction
     * @param requiredFee The required fee for the operation
     */
    function _validateFee(
        uint256 providedFee,
        uint256 requiredFee
    ) internal pure {
        if (providedFee < requiredFee) revert InsufficientFee();
    }

    /**
     * @dev Internal function to handle refunds safely
     * @param recipient Address to receive the refund
     * @param amount Amount to refund
     */
    function _refund(address recipient, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) revert TransferFailed();
        }
    }

    /**
     * @dev Internal function to generate a unique operation ID and set initial status
     * @param operationType Type of operation being performed
     * @param destinationChainId Target chain ID
     * @param asset Asset address (address(0) for non-asset operations)
     * @param amount Amount (0 for non-asset operations)
     * @param target Recipient address
     * @param additionalData Additional data for ID generation (contract address, selector, etc.)
     * @return operationId The generated operation ID
     */
    function _generateOperationId(
        BridgeTypes.OperationType operationType,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address target,
        bytes memory additionalData
    ) internal returns (bytes32 operationId) {
        // Use nonce for better uniqueness and collision resistance
        uint256 currentNonce = _useNonce(address(this));

        operationId = keccak256(
            abi.encode(
                block.chainid,
                destinationChainId,
                asset,
                amount,
                target,
                additionalData,
                currentNonce,
                operationType
            )
        );

        return operationId;
    }

    /**
     * @dev Internal function to apply fee buffer for cross-chain operation volatility
     * @param baseFee The base fee amount to buffer
     * @return bufferedFee The fee with 1% buffer applied
     */
    function _applyFeeBuffer(
        uint256 baseFee
    ) internal pure returns (uint256 bufferedFee) {
        // Add 1% buffer to account for fee volatility
        return (baseFee * 101) / 100;
    }

    /*//////////////////////////////////////////////////////////////
                           BRIDGE QUEUE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyAuthorizedExecutor
        whenNotPaused
        nonReentrant
        returns (bytes32 operationId)
    {
        _validateAdapterSupportsOperation(
            options.specifiedAdapter,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        _validateTransferParams(params);
        _validateOriginator(params.originator);

        // Get required base fee and specified adapter (no multiplier)
        (uint256 requiredBaseFee, , address specifiedAdapter) = _quote(
            params.destinationChainId,
            params.asset,
            params.amount,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Apply fee buffer to account for fee volatility
        uint256 bufferedFee = _applyFeeBuffer(requiredBaseFee);

        // Validate fee provided by authorized executor against buffered fee
        _validateFee(msg.value, bufferedFee);

        // Pull tokens from authorized executor to Router first
        IERC20(params.asset).safeTransferFrom(
            msg.sender, // authorized executor approved us
            address(this), // Transfer to Router
            params.amount
        );

        // Now approve the adapter to spend Router's tokens
        IERC20(params.asset).forceApprove(specifiedAdapter, params.amount);

        // Notify originator that assets are now officially in-flight
        // Attempt to call updateInflightAssets if the originator supports it
        if (params.originator.code.length > 0) {
            try
                IERC165(params.originator).supportsInterface(
                    type(IInflightAssetTracking).interfaceId
                )
            returns (bool supported) {
                if (supported) {
                    try
                        IInflightAssetTracking(params.originator)
                            .updateInflightAssets(params.amount)
                    {} catch {
                        // Ignore failures in updateInflightAssets
                    }
                }
            } catch {
                // Originator doesn't support ERC165 or IInflightAssetTracking, ignore
            }
        }

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.target,
            abi.encode(params.originator) // Additional data for uniqueness
        );

        // Call adapter with the full msg.value
        IAssetAdapter(specifiedAdapter).transferAsset{value: bufferedFee}(
            operationId, // Pass the router-generated ID
            params,
            options
        );

        // Refund any excess native fees to designated refund address
        _refund(params.refundAddress, msg.value - bufferedFee);

        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.target,
            specifiedAdapter
        );

        return operationId;
    }

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeReadState(
        BridgeTypes.ExecuteReadStateParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyAuthorizedExecutor
        whenNotPaused
        nonReentrant
        returns (bytes32 operationId)
    {
        _validateAdapterSupportsOperation(
            options.specifiedAdapter,
            BridgeTypes.OperationType.READ_STATE
        );
        _validateReadStateParams(params);
        _validateOriginator(params.originator);

        // Get required base fee and specified adapter (no multiplier)
        (uint256 requiredBaseFee, , address specifiedAdapter) = _quote(
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Apply fee buffer to account for fee volatility
        uint256 bufferedFee = _applyFeeBuffer(requiredBaseFee);

        // Validate fee provided by authorized executor against buffered fee
        _validateFee(msg.value, bufferedFee);

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            BridgeTypes.OperationType.READ_STATE,
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            address(0), // No target for read operations
            abi.encode(
                params.target,
                params.selector,
                params.readParams,
                params.originator
            )
        );

        // Only relevant for read operations
        operationToAdapter[operationId] = specifiedAdapter;

        // Store the originator for response delivery
        readRequestToOriginator[operationId] = params.originator;

        // Call adapter with the full msg.value
        IMessageAdapter(specifiedAdapter).readState{value: bufferedFee}(
            operationId, // Pass the router-generated ID
            params,
            options
        );

        // Refund any excess native fees to designated refund address
        _refund(params.refundAddress, msg.value - bufferedFee);

        emit ReadRequestInitiated(
            operationId,
            params.destinationChainId,
            params.target,
            params.selector,
            params.readParams,
            specifiedAdapter
        );

        return operationId;
    }

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyAuthorizedExecutor
        whenNotPaused
        nonReentrant
        returns (bytes32 operationId)
    {
        _validateAdapterSupportsOperation(
            options.specifiedAdapter,
            BridgeTypes.OperationType.MESSAGE
        );
        _validateSendMessageParams(params);
        _validateOriginator(params.originator);

        // Get required base fee and specified adapter (no multiplier)
        (uint256 requiredBaseFee, , address specifiedAdapter) = _quote(
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            options,
            BridgeTypes.OperationType.MESSAGE
        );

        // Apply fee buffer to account for fee volatility
        uint256 bufferedFee = _applyFeeBuffer(requiredBaseFee);

        // Validate fee provided by authorized executor against buffered fee
        _validateFee(msg.value, bufferedFee);

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            BridgeTypes.OperationType.MESSAGE,
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            params.target,
            abi.encode(params.message, params.originator)
        );

        // Call adapter with the full msg.value
        IMessageAdapter(specifiedAdapter).sendMessage{value: bufferedFee}(
            operationId, // Pass the router-generated ID
            params,
            options
        );

        // Refund any excess native fees to designated refund address
        _refund(params.refundAddress, msg.value - bufferedFee);

        emit MessageInitiated(
            operationId,
            params.destinationChainId,
            params.target,
            specifiedAdapter
        );

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal implementation of quote that validates the specified adapter and gets the base fee.
     * @param destinationChainId ID of the destination chain.
     * @param asset Address of the asset to transfer.
     * @param amount Amount of the asset to transfer.
     * @param options Additional options for the transfer.
     * @param operationType Type of operation being performed.
     * @return nativeFee Base fee in native token required by the adapter.
     * @return tokenFee Base fee in the asset token required by the adapter.
     * @return specifiedAdapter Address of the specified adapter.
     *
     * @dev Specified adapter is part of the return values in case
     * adapter auto-select is added in future.
     */
    function _quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions memory options,
        BridgeTypes.OperationType operationType
    )
        internal
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        specifiedAdapter = options.specifiedAdapter;

        // If no adapter specified, revert
        if (specifiedAdapter == address(0)) {
            revert NoSuitableAdapter();
        } else {
            // Validate specified adapter
            if (!this.isValidAdapter(specifiedAdapter)) {
                revert UnknownAdapter();
            }
        }

        // Get base fee from the specified adapter
        (nativeFee, tokenFee) = IBridgeAdapter(specifiedAdapter).estimateFee(
            destinationChainId,
            asset,
            amount,
            options,
            operationType
        );

        return (nativeFee, tokenFee, specifiedAdapter);
    }

    /// @inheritdoc IBridgeRouter
    function quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.OperationType operationType
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        // Get the base fee from internal quote
        (uint256 baseFee, uint256 baseTokenFee, address adapter) = _quote(
            destinationChainId,
            asset,
            amount,
            options,
            operationType
        );

        // Apply fee buffer to account for fee volatility
        uint256 bufferedNativeFee = _applyFeeBuffer(baseFee);

        return (bufferedNativeFee, baseTokenFee, adapter);
    }

    /// @inheritdoc IBridgeRouter
    function deliver(
        BridgeTypes.OperationType operationType,
        bytes calldata operationPayload
    ) external onlyRegisteredAdapter nonReentrant {
        bytes32 operationId;

        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory data = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedTransferParams)
            );

            // Additional defense: verify adapter has peer relationship with source chain
            _assertPeerMappingExistsForChain(data.sourceChainId);
            operationId = data.operationId;

            // Transfer the asset
            IERC20(data.asset).safeTransfer(data.recipient, data.amount);

            // Call appropriate receiver interface
            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.TRANSFER_ASSET,
                operationPayload
            );
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory data = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedMessageParams)
            );

            // Additional defense: verify adapter has peer relationship with source chain
            _assertPeerMappingExistsForChain(data.sourceChainId);
            operationId = data.operationId;

            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.MESSAGE,
                operationPayload
            );
        } else if (operationType == BridgeTypes.OperationType.READ_STATE) {
            BridgeTypes.RelayedReadResponse memory data = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedReadResponse)
            );

            // For read operations, skip peer verification since:
            // 1. Read responses are delivered by the same adapter that sent the request
            // 2. Authorization is already handled by operationToAdapter check below
            // 3. sourceChainId represents where the read was performed, not message origin

            // Only relevant for read operations which receive on the same chain as the originator
            operationId = data.operationId;

            if (operationToAdapter[data.operationId] != msg.sender) {
                revert Unauthorized();
            }

            address originator = readRequestToOriginator[data.operationId];
            if (originator == address(0)) revert InvalidParams();

            ICrossChainReceiver(originator).receiveOperation(
                BridgeTypes.OperationType.READ_STATE,
                operationPayload
            );
        } else {
            revert UnsupportedOperationType();
        }

        emit OperationDelivered(operationId, operationType);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function getAdapters() public view returns (address[] memory) {
        return adapters.values();
    }

    /// @inheritdoc IBridgeRouter
    function isValidAdapter(address adapter) external view returns (bool) {
        return adapters.contains(adapter);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function registerAdapter(address adapter) external onlyGovernor {
        if (adapters.contains(adapter)) revert AdapterAlreadyRegistered();

        adapters.add(adapter);
        emit AdapterRegistered(adapter);
    }

    /// @inheritdoc IBridgeRouter
    function removeAdapter(address adapter) external onlyGovernor {
        if (!adapters.contains(adapter)) revert UnknownAdapter();

        adapters.remove(adapter);
        emit AdapterRemoved(adapter);
    }

    /// @inheritdoc IBridgeRouter
    function pause() external onlyGuardianOrGovernor {
        paused = true;
    }

    /// @inheritdoc IBridgeRouter
    function unpause() external onlyGovernor {
        paused = false;
    }

    /// @inheritdoc IBridgeRouter
    function recoverAssets(
        address token,
        address recipient,
        uint256 amount
    ) external nonReentrant onlyGovernor {
        if (recipient == address(0)) revert InvalidParams();

        if (token == address(0)) {
            // Recover native ETH
            if (address(this).balance < amount) revert InsufficientBalance();
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Recover ERC20 using SafeERC20
            IERC20(token).safeTransfer(recipient, amount);
        }

        emit RouterAssetsRecovered(token, recipient, amount);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return (interfaceId == type(IBridgeRouter).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }
}
