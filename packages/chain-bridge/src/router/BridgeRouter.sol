// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";
import {Bps, BPS_FACTOR} from "../helpers/Bps.sol";
import {BpsUtils} from "../helpers/BpsUtils.sol";

import {BridgeRouterValidationBase} from "./base/BridgeRouterValidationBase.sol";
import {BridgeRouterFailureBase} from "./base/BridgeRouterFailureBase.sol";
import {BridgeRouterRecipientBase} from "./base/BridgeRouterRecipientBase.sol";
import {BridgeRouterDeliveryBase} from "./base/BridgeRouterDeliveryBase.sol";

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
    CrossChainConfigManaged,
    BridgeRouterValidationBase,
    BridgeRouterFailureBase,
    BridgeRouterRecipientBase,
    BridgeRouterDeliveryBase
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Set of registered adapters
    EnumerableSet.AddressSet private adapters;

    /// @notice Pause state of the router
    bool public paused;

    /// @notice Fee buffer in basis points for cross-chain operations
    Bps private feeBufferBps;

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
    ) ProtocolAccessManaged(accessManager) CrossChainConfigManaged(_registry) {
        // Initialize fee buffer to 1% (100 basis points)
        feeBufferBps = Bps.wrap(100);
    }

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

    /**
     * @dev Modifier ensuring the adapter is valid and supports the operation type.
     * Reverts with `UnknownAdapter` if the adapter is not valid.
     * Reverts with `UnsupportedAdapterOperation` if the adapter does not support the operation type.
     */
    modifier validAdapter(
        address adapter,
        BridgeTypes.OperationType operationType
    ) {
        // If no adapter specified, surface a dedicated error
        if (adapter == address(0)) revert NoSuitableAdapter();
        if (!adapters.contains(adapter)) revert UnknownAdapter();
        _validateAdapterSupportsOperation(adapter, operationType);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to generate a unique operation ID
     * @return operationId The generated operation ID
     */
    function _generateOperationId() internal returns (bytes32 operationId) {
        // Use nonce for better uniqueness and collision resistance
        uint256 currentNonce = _useNonce(address(this));

        operationId = keccak256(
            abi.encode(block.chainid, currentNonce, address(this))
        );

        return operationId;
    }

    /**
     * @dev Internal function to apply fee buffer for cross-chain operation volatility
     * @param baseFee The base fee amount to buffer
     * @return bufferedFee The fee with configured buffer applied
     */
    function _applyFeeBuffer(
        uint256 baseFee
    ) internal view returns (uint256 bufferedFee) {
        // Apply configured buffer to account for fee volatility
        return BpsUtils.applyBpsMarkup(baseFee, feeBufferBps);
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
        validAdapter(
            options.specifiedAdapter,
            BridgeTypes.OperationType.TRANSFER_ASSET
        )
        returns (bytes32 operationId)
    {
        if (options.gasLimit == 0) revert ZeroGasLimit();
        _validateTransferParams(params);
        _validateOriginator(params.originator);

        address specifiedAdapter = options.specifiedAdapter;

        // Pull tokens from authorized executor to Router first
        IERC20(params.asset).safeTransferFrom(
            msg.sender, // authorized executor approved us
            address(this), // Transfer to Router
            params.amount
        );

        // Now approve the adapter to spend Router's tokens
        IERC20(params.asset).forceApprove(specifiedAdapter, params.amount);

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId();

        // Call adapter with the full msg.value
        IAssetAdapter(specifiedAdapter).transferAsset{value: msg.value}(
            operationId, // Pass the router-generated ID
            params,
            options
        );

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
    function executeSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyAuthorizedExecutor
        whenNotPaused
        nonReentrant
        validAdapter(
            options.specifiedAdapter,
            BridgeTypes.OperationType.MESSAGE
        )
        returns (bytes32 operationId)
    {
        if (options.gasLimit == 0) revert ZeroGasLimit();
        _validateSendMessageParams(params);
        _validateOriginator(params.originator);

        address specifiedAdapter = options.specifiedAdapter;

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId();

        // Call adapter with the full msg.value
        IMessageAdapter(specifiedAdapter).sendMessage{value: msg.value}(
            operationId, // Pass the router-generated ID
            params,
            options
        );

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

    /// @inheritdoc IBridgeRouter
    function quoteTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        validAdapter(
            options.specifiedAdapter,
            BridgeTypes.OperationType.TRANSFER_ASSET
        )
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        specifiedAdapter = options.specifiedAdapter;

        if (options.gasLimit == 0) revert ZeroGasLimit();

        _validateTransferParams(params);
        (nativeFee, tokenFee) = IAssetAdapter(specifiedAdapter)
            .estimateTransferAssets(params, options);

        nativeFee = _applyFeeBuffer(nativeFee);
        tokenFee = _applyFeeBuffer(tokenFee);
    }

    /// @inheritdoc IBridgeRouter
    function quoteSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        specifiedAdapter = options.specifiedAdapter;
        if (specifiedAdapter == address(0)) revert NoSuitableAdapter();
        if (!adapters.contains(specifiedAdapter)) revert UnknownAdapter();

        _validateSendMessageParams(params);
        (nativeFee, tokenFee) = IMessageAdapter(specifiedAdapter)
            .estimateSendMessage(params, options);

        nativeFee = _applyFeeBuffer(nativeFee);
        tokenFee = _applyFeeBuffer(tokenFee);
    }

    /// @inheritdoc IBridgeRouter
    function deliver(
        BridgeTypes.OperationType operationType,
        bytes calldata operationPayload
    ) external onlyRegisteredAdapter nonReentrant {
        // Pre-decode minimal fields for logging/recording
        DecodedOperationData memory data = _decodeCommonOperationData(
            operationType,
            operationPayload
        );
        bytes32 operationId = data.operationId;
        uint16 sourceChainId = data.sourceChainId;

        // Attempt processing in a self-call so we can capture reverts without
        // rolling back the outer call (adapter delivery pathway)
        try this.processDelivery(operationType, operationPayload, msg.sender) {
            // Success path - clear any existing failure record for this operation
            _clearFailedDelivery(operationId);
            emit OperationDelivered(operationId, operationType);
        } catch (bytes memory err) {
            _recordFailedDelivery(
                operationId,
                operationType,
                msg.sender,
                sourceChainId,
                operationPayload,
                err
            );
            // Do not revert; from the interchain messaging protocol perspective, the transaction is considered successful even if delivery failed here
            // This allows us to retry failed deliveries without trapping a message with the underlying interchain messaging protocol
        }
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

    /// @inheritdoc IBridgeRouter
    function getFeeBufferBps() external view returns (Bps) {
        return feeBufferBps;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function registerAdapter(address adapter) external onlyGovernor {
        if (adapters.contains(adapter)) revert AdapterAlreadyRegistered();
        if (adapter == address(0)) revert InvalidParams();
        if (adapter.code.length == 0) revert InvalidParams(); // prevent EOA registration
        // Require ERC-165 support for IBridgeAdapter
        if (
            !ERC165Checker.supportsInterface(
                adapter,
                type(IBridgeAdapter).interfaceId
            )
        ) {
            revert InvalidParams();
        }

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
        emit RouterPaused(msg.sender);
    }

    /// @inheritdoc IBridgeRouter
    function unpause() external onlyGovernor {
        paused = false;
        emit RouterUnpaused(msg.sender);
    }

    /// @inheritdoc IBridgeRouter
    function sweep(
        address token,
        address recipient,
        uint256 amount
    ) external nonReentrant onlyGovernor {
        if (recipient == address(0)) revert InvalidParams();

        if (token == address(0)) {
            // Recover native ETH
            if (address(this).balance < amount) revert InsufficientBalance();
            Address.sendValue(payable(recipient), amount);
        } else {
            // Recover ERC20 using SafeERC20
            IERC20(token).safeTransfer(recipient, amount);
        }

        emit RouterAssetsRecovered(token, recipient, amount);
    }

    /// @inheritdoc IBridgeRouter
    function setFeeBufferBps(Bps newBufferBps) external onlyGovernor {
        // Validate buffer is within allowed range (1% to 10%)
        if (Bps.unwrap(newBufferBps) < 100 || Bps.unwrap(newBufferBps) > 1000) {
            revert InvalidFeeBuffer();
        }

       emit FeeBufferUpdated(
            Bps.unwrap(feeBufferBps),
            Bps.unwrap(newBufferBps)
        );
        
        feeBufferBps = newBufferBps;
       
    }

    /// @notice Retries a previously failed delivery with optional recipient override. Only callable by keeper.
    /// @param operationId The failed operation identifier
    /// @param newRecipient New recipient address; pass address(0) to use original recipient
    function retryFailedDelivery(
        bytes32 operationId,
        address newRecipient
    ) external nonReentrant onlyKeeper whenNotPaused {
        FailedDeliveryRecord memory r = failedDeliveries[operationId];

        if (r.failedAt == 0) revert InvalidParams();

        // Use the original adapter - no override needed
        address effectiveAdapter = r.adapter;

        // Retrieve the payload from the failed delivery record
        bytes memory effectivePayload = r.operationPayload;

        // Apply recipient override if provided
        // validation happens inside _applyRecipientOverride
        effectivePayload = _applyRecipientOverride(
            r.operationType,
            effectivePayload,
            newRecipient
        );

        try
            this.processDelivery(
                r.operationType,
                effectivePayload,
                effectiveAdapter
            )
        {
            _clearFailedDelivery(operationId);
            emit OperationRetrySucceeded(
                operationId,
                r.operationType,
                effectiveAdapter
            );
        } catch (bytes memory err) {
            // Do not create a new failure record; update existing metadata only
            FailedDeliveryRecord storage existing = failedDeliveries[
                operationId
            ];
            existing.failedAt = block.timestamp;

            emit OperationRetryFailed(
                operationId,
                r.operationType,
                effectiveAdapter,
                err
            );
        }
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return (interfaceId == type(IBridgeRouter).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }
}
