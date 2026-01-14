// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title TimelockGuard
 * @notice A single-use guard contract that enforces a minimum execution timestamp for governance timelock transactions
 * @dev This contract is designed to be used as an additional layer of protection for permissionless timelock transactions.
 *      It ensures that certain actions cannot be executed before a specified timestamp, even if they are otherwise
 *      permissionless to execute.
 *
 * @custom:usage Governance timelock transactions that are permissionless to execute but require a "not earlier than"
 *              constraint can deploy this contract and call `validateTimestamp()` before executing the protected action.
 *              If the current block timestamp is before the guard's minimum timestamp, the transaction will revert.
 *
 * @custom:security This contract is immutable after deployment. The minimum timestamp cannot be changed, ensuring
 *                  that the guard's behavior is predictable and cannot be manipulated.
 */
contract TimelockGuard {
    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Reverts when an action is attempted before the minimum allowed timestamp
     * @dev Emitted when `validateTimestamp()` is called and `block.timestamp < minimumTimestamp`
     */
    error TimelockGuard__TooEarly();

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The minimum timestamp (inclusive) at which the guarded action can be executed
     * @dev Set during construction and immutable thereafter. Actions executed before this timestamp will revert.
     *      Uses Unix timestamp format (seconds since epoch).
     */
    uint256 public immutable minimumTimestamp;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the TimelockGuard with a minimum execution timestamp
     * @param _minimumTimestamp The earliest timestamp (inclusive) at which the guarded action can be executed
     *                          Must be a valid Unix timestamp (seconds since epoch)
     * @dev The contract is immutable after deployment. The minimum timestamp cannot be changed.
     *      If `_minimumTimestamp` is set to a past timestamp, the guard will immediately allow execution.
     */
    constructor(uint256 _minimumTimestamp) {
        minimumTimestamp = _minimumTimestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that the current block timestamp meets the minimum requirement
     * @dev Reverts with `TimelockGuard__TooEarly` if `block.timestamp < minimumTimestamp`.
     *      This function should be called before executing any protected action in a governance timelock transaction.
     *
     * @custom:example
     * ```solidity
     * // In your governance timelock transaction:
     * TimelockGuard guard = TimelockGuard(guardAddress);
     * guard.validateTimestamp(); // Reverts if too early
     * // Proceed with protected action...
     * ```
     *
     */
    function validateTimestamp() public {
        if (block.timestamp < minimumTimestamp) {
            revert TimelockGuard__TooEarly();
        }
    }
}
