// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "./FleetCommander.sol";
import {ICrossChainFleetCommander} from "../interfaces/ICrossChainFleetCommander.sol";
import {AsyncOperation, CrossChainFleetCommanderParams} from "../types/CrossChainFleetCommanderTypes.sol";
import {FleetCommanderParams} from "../types/FleetCommanderTypes.sol";
import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ICrossChainFleetCommanderErrors} from "../errors/ICrossChainFleetCommanderErrors.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title CrossChainFleetCommander
 * @notice FleetCommander variant with async deposits/withdrawals to prevent MEV attacks
 * @dev Implements a queue-based system where deposits/withdrawals are queued and processed
 *      by superkeepers only when all Arks are synced with remote state
 */
contract CrossChainFleetCommander is FleetCommander, ICrossChainFleetCommander {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    // Custom errors are now defined in ICrossChainFleetCommanderErrors.sol

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of operation ID to async operation
    mapping(uint256 => AsyncOperation) public asyncOperations;

    /// @notice Array of queued operation IDs (FIFO queue)
    uint256[] public operationQueue;

    /// @notice Next operation ID to assign
    uint256 public nextOperationId = 1;

    /// @notice Total number of queued operations
    uint256 public queuedOperationsCount;

    /// @notice Maximum number of operations that can be queued
    uint256 public constant MAX_QUEUE_SIZE = 500;

    /// @notice Minimum amount for queue operations (in asset units)
    uint256 public immutable minQueueAmount;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChain FleetCommander
     * @param params CrossChainFleetCommanderParams struct containing initialization parameters
     */
    constructor(
        CrossChainFleetCommanderParams memory params
    )
        FleetCommander(
            FleetCommanderParams({
                name: params.name,
                details: params.details,
                symbol: params.symbol,
                configurationManager: params.configurationManager,
                accessManager: params.accessManager,
                asset: params.asset,
                initialMinimumBufferBalance: params.initialMinimumBufferBalance,
                initialRebalanceCooldown: params.initialRebalanceCooldown,
                depositCap: params.depositCap,
                initialTipRate: params.initialTipRate
            })
        )
    {
        minQueueAmount = params.minQueueAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to ensure all Arks are synced before processing
     * @dev This is the key MEV protection - operations only process when state is current
     */
    modifier allArksSynced() {
        if (!areAllArksSynced()) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderNotAllArksSynced();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            ASYNC OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainFleetCommander
    function queueDeposit(
        uint256 assets,
        address receiver
    ) external whenNotPaused returns (uint256 operationId) {
        if (assets < minQueueAmount) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderAmountBelowMinimum(
                    assets,
                    minQueueAmount
                );
        }
        _validateDeposit(assets, _msgSender());

        operationId = _queueOperation(
            AsyncOperation({
                user: _msgSender(),
                receiver: receiver,
                amount: assets,
                shares: 0,
                timestamp: block.timestamp,
                operationType: 0, // deposit
                processed: false
            })
        );

        emit AsyncOperationQueued(
            operationId,
            _msgSender(),
            0,
            assets,
            block.timestamp
        );
    }

    /// @inheritdoc ICrossChainFleetCommander
    function queueWithdrawal(
        uint256 assets,
        address receiver,
        address owner
    ) external whenNotPaused returns (uint256 operationId) {
        if (assets < minQueueAmount) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderAmountBelowMinimum(
                    assets,
                    minQueueAmount
                );
        }
        uint256 shares = previewWithdraw(assets);
        _validateWithdrawFromArks(assets, shares, owner);

        operationId = _queueOperation(
            AsyncOperation({
                user: _msgSender(),
                receiver: receiver,
                amount: assets,
                shares: shares,
                timestamp: block.timestamp,
                operationType: 1, // withdrawal
                processed: false
            })
        );

        emit AsyncOperationQueued(
            operationId,
            _msgSender(),
            1,
            assets,
            block.timestamp
        );
    }

    /// @inheritdoc ICrossChainFleetCommander
    function queueRedemption(
        uint256 shares,
        address receiver,
        address owner
    ) external whenNotPaused returns (uint256 operationId) {
        _validateRedeemFromArks(shares, owner);
        uint256 assets = previewRedeem(shares);

        operationId = _queueOperation(
            AsyncOperation({
                user: _msgSender(),
                receiver: receiver,
                amount: assets,
                shares: shares,
                timestamp: block.timestamp,
                operationType: 2, // redemption
                processed: false
            })
        );

        emit AsyncOperationQueued(
            operationId,
            _msgSender(),
            2,
            shares,
            block.timestamp
        );
    }

    /*//////////////////////////////////////////////////////////////
                            SUPERKEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainFleetCommander
    function processAsyncOperations(
        uint256 maxOperations
    )
        external
        onlyKeeper
        allArksSynced
        collectTip
        whenNotPaused
        returns (uint256 processedCount, uint256 failedCount)
    {
        uint256 operationsToProcess = Math.min(
            maxOperations,
            operationQueue.length
        );
        uint256[] memory processedOperationIds = new uint256[](
            operationsToProcess
        );

        for (uint256 i = 0; i < operationsToProcess; i++) {
            uint256 operationId = operationQueue[i];
            AsyncOperation storage operation = asyncOperations[operationId];

            // Skip if already processed
            if (operation.processed) {
                continue;
            }

            try this._processOperation(operationId) {
                processedCount++;
                processedOperationIds[i] = operationId;
            } catch {
                failedCount++;
            }
        }

        // Remove processed operations from queue
        _removeProcessedOperations(processedOperationIds, processedCount);

        emit AsyncOperationsProcessed(
            processedOperationIds,
            processedCount,
            failedCount
        );
    }

    /// @inheritdoc ICrossChainFleetCommander
    function cancelOperation(uint256 operationId) external {
        AsyncOperation storage operation = asyncOperations[operationId];
        if (operation.processed) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderOperationAlreadyProcessedForCancellation(
                    operationId
                );
        }
        if (operation.user != _msgSender()) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderNotYourOperation(
                    operationId,
                    _msgSender(),
                    operation.user
                );
        }

        _cancelOperation(operationId);
        emit AsyncOperationCancelled(operationId, operation.user);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Queue a new async operation
     * @param operation The operation to queue
     * @return operationId The ID of the queued operation
     */
    function _queueOperation(
        AsyncOperation memory operation
    ) internal returns (uint256 operationId) {
        // Check queue size limit
        if (operationQueue.length >= MAX_QUEUE_SIZE) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderQueueFull(
                    operationQueue.length,
                    MAX_QUEUE_SIZE
                );
        }

        // Check minimum amount for deposits and withdrawals
        if (operation.operationType == 0 || operation.operationType == 1) {
            if (operation.amount < minQueueAmount) {
                revert ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderAmountBelowMinimum(
                        operation.amount,
                        minQueueAmount
                    );
            }
        }

        operationId = nextOperationId++;
        asyncOperations[operationId] = operation;
        operationQueue.push(operationId);
        queuedOperationsCount++;
    }

    /**
     * @notice Process a single async operation
     * @param operationId The ID of the operation to process
     */
    function _processOperation(uint256 operationId) external {
        AsyncOperation storage operation = asyncOperations[operationId];
        if (operation.processed) {
            revert ICrossChainFleetCommanderErrors
                .CrossChainFleetCommanderOperationAlreadyProcessed(operationId);
        }

        if (operation.operationType == 0) {
            // Deposit operation
            _processDeposit(operation);
        } else if (operation.operationType == 1) {
            // Withdrawal operation
            _processWithdrawal(operation);
        } else if (operation.operationType == 2) {
            // Redemption operation
            _processRedemption(operation);
        }

        operation.processed = true;
    }

    /**
     * @notice Process a deposit operation
     * @param operation The operation to process
     */
    function _processDeposit(AsyncOperation memory operation) internal {
        _validateDeposit(operation.amount, operation.user);

        _internalDeposit(operation.amount, operation.receiver, operation.user);
    }

    /**
     * @notice Process a withdrawal operation
     * @param operation The operation to process
     */
    function _processWithdrawal(AsyncOperation memory operation) internal {
        uint256 shares = previewWithdraw(operation.amount);
        _validateWithdrawFromArksForAsync(
            operation.amount,
            shares,
            operation.user
        );

        _internalWithdraw(
            operation.amount,
            operation.receiver,
            operation.user,
            operation.user
        );
    }

    /**
     * @notice Process a redemption operation
     * @param operation The operation to process
     */
    function _processRedemption(AsyncOperation memory operation) internal {
        _validateRedeemFromArksForAsync(operation.shares, operation.user);

        _internalRedeem(
            operation.shares,
            operation.receiver,
            operation.user,
            operation.user
        );
    }

    /**
     * @notice Cancel an operation
     * @param operationId The ID of the operation to cancel
     */
    function _cancelOperation(uint256 operationId) internal {
        asyncOperations[operationId].processed = true;
        queuedOperationsCount--;
    }

    /**
     * @notice Validate withdrawal for async operations (no allowance check needed)
     * @param assets The amount of assets to withdraw
     * @param shares The number of shares to redeem
     * @param owner The address of the owner of the shares
     */
    function _validateWithdrawFromArksForAsync(
        uint256 assets,
        uint256 shares,
        address owner
    ) internal view {
        if (shares == 0) {
            revert FleetCommanderZeroAmount();
        }
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }
    }

    /**
     * @notice Validate redemption for async operations (no allowance check needed)
     * @param shares The number of shares to redeem
     * @param owner The address of the owner of the shares
     */
    function _validateRedeemFromArksForAsync(
        uint256 shares,
        address owner
    ) internal view {
        if (shares == 0) {
            revert FleetCommanderZeroAmount();
        }
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }
    }

    /**
     * @notice Remove processed operations from the queue
     * @param processedOperationIds Array of processed operation IDs
     * @param processedCount Number of operations that were actually processed
     */
    function _removeProcessedOperations(
        uint256[] memory processedOperationIds,
        uint256 processedCount
    ) internal {
        // Remove processed operations from the front of the queue
        for (uint256 i = 0; i < processedCount; i++) {
            if (operationQueue.length > 0) {
                // Remove the first element (FIFO)
                for (uint256 j = 0; j < operationQueue.length - 1; j++) {
                    operationQueue[j] = operationQueue[j + 1];
                }
                operationQueue.pop();
                queuedOperationsCount--;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainFleetCommander
    function getAsyncOperation(
        uint256 operationId
    ) external view returns (AsyncOperation memory operation) {
        return asyncOperations[operationId];
    }

    /// @inheritdoc ICrossChainFleetCommander
    function getQueuedOperationsCount() external view returns (uint256 count) {
        return queuedOperationsCount;
    }

    /// @inheritdoc ICrossChainFleetCommander
    function getNextOperationId() external view returns (uint256 operationId) {
        if (operationQueue.length == 0) {
            return 0;
        }
        return operationQueue[0];
    }

    /// @inheritdoc ICrossChainFleetCommander
    function areAllArksSynced() public view returns (bool synced) {
        address[] memory activeArks = getActiveArks();

        for (uint256 i = 0; i < activeArks.length; i++) {
            if (!IArk(activeArks[i]).isSynced()) {
                return false;
            }
        }

        // Also check buffer ark
        if (!IArk(address(config.bufferArk)).isSynced()) {
            return false;
        }

        return true;
    }

    /// @notice Get the minimum amount for queue operations
    function getMinQueueAmount() external view returns (uint256 amount) {
        return minQueueAmount;
    }

    /// @notice Get the maximum queue size
    function getMaxQueueSize() external pure returns (uint256 size) {
        return MAX_QUEUE_SIZE;
    }

    /// @inheritdoc IFleetCommander
    function totalAssets()
        public
        view
        override(FleetCommander, IFleetCommander)
        returns (uint256)
    {
        return _totalAssets(config.bufferArk);
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDDEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Override deposit to prevent immediate execution
     * @dev This prevents immediate execution that could be MEV'd
     * @dev Users must use queueDeposit() for async operations
     */
    function deposit(
        uint256 assets,
        address receiver
    ) public override(FleetCommander, IERC4626) returns (uint256 shares) {
        revert ICrossChainFleetCommanderErrors
            .CrossChainFleetCommanderUseAsyncFunction(
                "Use queueDeposit() for async operations"
            );
    }

    /**
     * @notice Override withdraw to prevent immediate execution
     * @dev This prevents immediate execution that could be MEV'd
     * @dev Users must use queueWithdrawal() for async operations
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override(FleetCommander, IFleetCommander)
        returns (uint256 shares)
    {
        revert ICrossChainFleetCommanderErrors
            .CrossChainFleetCommanderUseAsyncFunction(
                "Use queueWithdrawal() for async operations"
            );
    }

    /**
     * @notice Override redeem to prevent immediate execution
     * @dev This prevents immediate execution that could be MEV'd
     * @dev Users must use queueRedemption() for async operations
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override(FleetCommander, IFleetCommander)
        returns (uint256 assets)
    {
        revert ICrossChainFleetCommanderErrors
            .CrossChainFleetCommanderUseAsyncFunction(
                "Use queueRedemption() for async operations"
            );
    }
}
