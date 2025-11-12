// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ISummerVestingWalletsEscrow
 * @notice Interface for the escrow that allows staking xSUMR against SUMR balances held in vesting wallets.
 * @dev Implementations MUST enforce access control (governor) where specified and adhere to the documented
 *      revert conditions to ensure consistent behavior across integrations and tests.
 *
 * High-level Design:
 * - Users can stake governance power (xSUMR minted 1:1) against SUMR held in vesting wallets owned by the escrow.
 * - During stake, the escrow must be the owner of the vesting wallets; on unstake, ownership returns to the user.
 * - Any SUMR released while staked (via permissionless `release`) is forwarded to the user during unstake.
 * - Factories producing vesting wallets are allowlisted by governance; users can only stake from enabled factories.
 *
 * Security Considerations:
 * - Ownership precondition is enforced on stake/unstake to prevent accidental custody assumptions.
 * - The escrow never moves SUMR from the vesting wallet; it only accounts balances and mints/burns xSUMR.
 * - Rescue methods are governance-only and are intended as last-resort controls.
 */
interface ISummerVestingWalletsEscrow {
    // =============================
    //            EVENTS
    // =============================

    /**
     * @notice Emitted when a vesting factory is added to the allowed set.
     * @param vestingFactory Address of the vesting factory added.
     */
    event VestingFactoryAdded(address indexed vestingFactory);

    /**
     * @notice Emitted when a vesting factory is removed from the allowed set.
     * @param vestingFactory Address of the vesting factory removed.
     */
    event VestingFactoryRemoved(address indexed vestingFactory);

    /**
     * @notice Emitted when user staked a vesting wallet
     * @param user The user that staked the vesting wallet
     * @param vestingFactory The vesting factory that the user staked from
     * @param balance The balance of the vesting wallet at the time of staking
     * @param released The amount released from the vesting wallet at the time of staking
     */
    event StakedVestingWallet(
        address indexed user,
        address indexed vestingFactory,
        uint256 balance,
        uint256 released
    );

    /**
     * @notice Emitted when user unstaked a vesting wallet
     * @param user The user that unstaked the vesting wallet
     * @param vestingFactory The vesting factory that the user unstaked from
     * @param balance The amount originally staked from the vesting wallet
     * @param released The amount released from the vesting wallet at the time of unstaking
     */
    event UnstakedVestingWallet(
        address indexed user,
        address indexed vestingFactory,
        uint256 balance,
        uint256 released
    );

    // =============================
    //            ERRORS
    // =============================

    /**
     * @notice Thrown when a zero address or otherwise invalid address is supplied.
     * @param message Additional context for the invalid address error.
     */
    error Staking_InvalidAddress(string message);

    /**
     * @notice Thrown when a vesting wallet ownership is invalid for the attempted operation.
     * @dev Used when the staking contract is not the current owner of the vesting wallet during stake/unstake flows.
     * @param message Additional context for the invalid owner error.
     */
    error Staking_InvalidOwner(string message);

    /// @notice Thrown when an index is out of bounds for vesting factory queries.
    error Staking_InvalidIndex();

    /// @notice Thrown when attempting to add a vesting factory that already exists.
    error Staking_DuplicateFactory();

    /// @notice Thrown when attempting to remove a vesting factory that is not present.
    error Staking_FactoryNotFound();

    /// @notice Reserved for potential future use if balance sanity checks are required.
    error Staking_InvalidBalance();

    /// @notice Thrown when attempting to operate on a factory that is not enabled for staking.
    error Staking_FactoryNotEnabled();

    /// @notice Thrown when attempting to stake from a factory with zero SUMR balance.
    error Staking_ZeroBalance();

    /// @notice Thrown when attempting to unstake a factory that has not been staked by the caller.
    error Staking_NoStakeForFactory();

    /// @notice Thrown when attempting to stake a factory that is already staked by the caller.
    error Staking_FactoryAlreadyStaked();

    // =============================
    //         VIEW METHODS
    // =============================

    /// @notice Returns the list of enabled vesting factories.
    /// @return factories An array of vesting factory addresses currently allowed.
    function vestingFactories()
        external
        view
        returns (address[] memory factories);

    /// @notice Returns the vesting factory at a given index.
    /// @dev Reverts if the index is out of bounds.
    /// @param index The index in the enabled vesting factories set.
    /// @return factory The vesting factory address at the given index.
    /// @custom:reverts Staking_InvalidIndex If `index` is >= number of factories.
    function getVestingFactory(
        uint256 index
    ) external view returns (address factory);

    /// @notice Returns the list of vesting factories from which the user has staked.
    /// @param user The user to query.
    /// @return factories Array of vesting factory addresses the user has staked from.
    function userStakedVestingFactories(
        address user
    ) external view returns (address[] memory factories);

    /// @notice Returns the vesting factory address at `index` for a given user.
    /// @dev Reverts if the index is out of bounds for the user's list.
    /// @param user The user to query.
    /// @param index Index into the user's staked vesting factories list.
    /// @return factory The vesting factory address.
    function getUserStakedVestingFactory(
        address user,
        uint256 index
    ) external view returns (address factory);

    // =============================
    //        GOVERNANCE METHODS
    // =============================

    /// @notice Adds a new vesting factory to the allowed set.
    /// @dev Access restricted to governor in implementing contract.
    /// @param vestingFactory The vesting factory address to add. Must be non-zero and not already present.
    /// @custom:reverts Staking_InvalidAddress If `vestingFactory` is the zero address.
    /// @custom:reverts Staking_DuplicateFactory If `vestingFactory` already exists in the set.
    /// @custom:emits VestingFactoryAdded Emitted upon successful addition.
    function addVestingFactory(address vestingFactory) external;

    /// @notice Removes a vesting factory from the allowed set.
    /// @dev Access restricted to governor in implementing contract.
    /// @param vestingFactory The vesting factory address to remove. Must be non-zero and present.
    /// @custom:reverts Staking_InvalidAddress If `vestingFactory` is the zero address.
    /// @custom:reverts Staking_FactoryNotFound If `vestingFactory` is not present in the set.
    /// @custom:emits VestingFactoryRemoved Emitted upon successful removal.
    function removeVestingFactory(address vestingFactory) external;

    /// @notice Transfers ownership of a vesting wallet to a new owner.
    /// @dev Access restricted to governor in implementing contract. This is an emergency escape hatch; governance is
    ///      responsible for downstream reconciliation of any tokens associated with the vesting wallet.
    /// @param wallet The vesting wallet address whose ownership will be transferred.
    /// @param newOwner The new owner address. Must be non-zero.
    /// @custom:reverts Staking_InvalidAddress If `newOwner` is the zero address.
    function rescueWallet(address wallet, address newOwner) external;

    /// @notice Transfers any balance of an ERC-20 token held by the escrow to a specified address.
    /// @dev Access restricted to governor in implementing contract.
    /// @param token The ERC-20 token address to rescue.
    /// @param to The recipient of the rescued tokens.
    function rescueToken(address token, address to) external;

    // =============================
    //          USER FLOWS
    // =============================

    /// @notice Stakes against the SUMR balances held in the caller's vesting wallets for the specified factories.
    /// @dev Each factory is processed independently; for each factory this will record the staked balance and released
    ///      amount, and mint xSUMR equal to the vesting wallet SUMR balance for that factory.
    /// @param factories The list of vesting factory addresses to stake from.
    /// @custom:reverts Staking_FactoryNotEnabled If a specified factory is not enabled.
    /// @custom:reverts Staking_FactoryAlreadyStaked If a specified factory is already staked for the caller.
    /// @custom:reverts Staking_InvalidOwner If the vesting wallet is not owned by the escrow.
    /// @custom:reverts Staking_ZeroBalance If the vesting wallet SUMR balance is zero.
    function stakeVesting(address[] calldata factories) external;

    /// @notice Unstakes previously staked vesting positions for the specified factories and returns vesting wallet
    ///         ownership back to the user for each.
    /// @dev Each factory is processed independently; this burns xSUMR equal to the recorded staked balance for that
    ///      factory and transfers vesting wallet ownership back to the original owner. Any SUMR released while staked
    ///      is forwarded to the original owner. user has to approve the escrow to burn xSUMR.
    /// @param factories The list of vesting factory addresses to unstake.
    /// @custom:reverts Staking_NoStakeForFactory If a specified factory has not been staked by the caller.
    /// @custom:reverts Staking_InvalidOwner If the vesting wallet is not owned by the escrow.
    function unstakeVesting(address[] calldata factories) external;
}
