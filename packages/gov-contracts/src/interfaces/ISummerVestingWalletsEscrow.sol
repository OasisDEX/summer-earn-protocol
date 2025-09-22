// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @title ISummerVestingWalletsEscrow
/// @notice Interface for the escrow that allows staking xSUMR against SUMR balances held in vesting wallets.
/// @dev Implementations MUST enforce access control (governor) where specified and adhere to the documented
///      revert conditions to ensure consistent behavior across integrations and tests.
interface ISummerVestingWalletsEscrow {
    // =============================
    //            EVENTS
    // =============================

    /// @notice Emitted when a vesting factory is added to the allowed set.
    /// @param vestingFactory Address of the vesting factory added.
    event VestingFactoryAdded(address indexed vestingFactory);

    /// @notice Emitted when a vesting factory is removed from the allowed set.
    /// @param vestingFactory Address of the vesting factory removed.
    event VestingFactoryRemoved(address indexed vestingFactory);

    /// @notice Emitted when suer staked a vesting wallet
    /// @param user The user that staked the vesting wallet
    /// @param vestingFactory The vesting factory that the user staked from
    /// @param balance The balance of the vesting wallet at the time of staking
    /// @param released The amount released from the vesting wallet at the time of staking
    event StakedVestingWallet(
        address indexed user,
        address indexed vestingFactory,
        uint256 balance,
        uint256 released
    );

    /// @notice Emitted when user unstaked a vesting wallet
    /// @param user The user that unstaked the vesting wallet
    /// @param vestingFactory The vesting factory that the user unstaked from
    /// @param balance The amount originally staked from the vesting wallet
    /// @param released The amount released from the vesting wallet at the time of unstaking
    event UnstakedVestingWallet(
        address indexed user,
        address indexed vestingFactory,
        uint256 balance,
        uint256 released
    );

    // =============================
    //            ERRORS
    // =============================

    /// @notice Thrown when a zero address or otherwise invalid address is supplied.
    /// @param message Additional context for the invalid address error.
    error Staking_InvalidAddress(string message);

    /// @notice Thrown when a vesting wallet ownership is invalid for the attempted operation.
    /// @dev Used when the staking contract is not the current owner of the vesting wallet during stake/unstake flows.
    /// @param message Additional context for the invalid owner error.
    error Staking__InvalidOwner(string message);

    /// @notice Thrown when an index is out of bounds for vesting factory queries.
    error Staking_InvalidIndex();

    /// @notice Thrown when attempting to add a vesting factory that already exists.
    error Staking_DuplicateFactory();

    /// @notice Thrown when attempting to remove a vesting factory that is not present.
    error Staking_FactoryNotFound();

    /// @notice Reserved for potential future use if balance sanity checks are required.
    error Staking_InvalidBalance();

    /// @notice Thrown when no eligible vesting wallets are found to stake from.
    /// @dev This includes the case where wallets have zero balance or have already been staked from for the caller.
    error Staking_VestingWalletsEmpty();

    /// @notice Thrown when there are no vesting wallets recorded as staked for the caller during an unstake attempt.
    error Staking_NoVestingWalletsStaked();

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

    /// @notice Stakes based on the SUMR balances held in the caller's vesting wallets across all enabled factories.
    /// @dev For each factory, if a vesting wallet exists for the caller and is currently owned by the staking contract,
    ///      and has not previously been staked from by the caller, its SUMR balance contributes to the minted xSUMR.
    ///      No tokens move out of the vesting wallets; the contract only verifies ownership and balances and mints xSUMR.
    /// @custom:reverts Staking_VestingWalletsEmpty If no eligible vesting wallets were found (zero total balance or
    ///                                            already staked).
    function stakeVesting() external;

    /// @notice Unstakes previously staked vesting positions and returns vesting wallet ownership back to the user.
    /// @dev Burns the caller's xSUMR equal to the previously staked total and transfers ownership of the vesting
    ///      wallets back to the original owner if still applicable. If any SUMR vested while staked, it is forwarded
    ///      to the original vesting wallet owner.
    /// @custom:reverts Staking_NoVestingWalletsStaked If the caller has no recorded staked vesting factories.
    function unstakeVesting() external;
}
