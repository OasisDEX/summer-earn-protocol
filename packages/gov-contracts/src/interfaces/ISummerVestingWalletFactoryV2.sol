// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerVestingWalletV2} from "./ISummerVestingWalletV2.sol";

interface ISummerVestingWalletFactoryV2 {
    //////////////////////////////////////////////
    ///                 ERRORS                 ///
    //////////////////////////////////////////////

    /// @dev Thrown when zero token address is provided
    error ZeroTokenAddress();

    /// @dev Thrown when insufficient allowance for token transfer
    error InsufficientAllowance(uint256 required, uint256 actual);

    /// @dev Thrown when insufficient balance for token transfer
    error InsufficientBalance(uint256 required, uint256 actual);

    /// @dev Thrown when transfer amount doesn't match expected
    error TransferAmountMismatch(uint256 expected, uint256 actual);

    /// @dev Thrown when vesting wallet already exists for beneficiary
    error VestingWalletAlreadyExists(address beneficiary);

    //////////////////////////////////////////////
    ///                 EVENTS                 ///
    //////////////////////////////////////////////

    /**
     * @notice Emitted when a new vesting wallet is created
     * @param beneficiary The address of the beneficiary
     * @param vestingWallet The address of the created vesting wallet
     * @param vestingParams The vesting parameters
     * @param performanceGoalsCount The number of initial performance goals
     */
    event VestingWalletCreated(
        address indexed beneficiary,
        address indexed vestingWallet,
        ISummerVestingWalletV2.VestingParams vestingParams,
        uint256 performanceGoalsCount
    );

    //////////////////////////////////////////////
    ///           MUTATIVE FUNCTIONS           ///
    //////////////////////////////////////////////

    /**
     * @notice Creates a new vesting wallet for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param vestingParams The vesting parameters
     * @param performanceGoals Initial performance goals
     * @return newVestingWallet The address of the created vesting wallet
     */
    function createVestingWallet(
        address beneficiary,
        ISummerVestingWalletV2.VestingParams memory vestingParams,
        ISummerVestingWalletV2.PerformanceGoal[] memory performanceGoals
    ) external returns (address newVestingWallet);

    //////////////////////////////////////////////
    ///             VIEW FUNCTIONS             ///
    //////////////////////////////////////////////

    /**
     * @notice Gets the vesting wallet address for a given beneficiary
     * @param beneficiary The address of the beneficiary
     * @return The address of the vesting wallet
     */
    function vestingWallets(
        address beneficiary
    ) external view returns (address);

    /**
     * @notice Gets the beneficiary of a vesting wallet
     * @param vestingWallet The address of the vesting wallet
     * @return The address of the beneficiary
     */
    function vestingWalletOwners(
        address vestingWallet
    ) external view returns (address);

    /**
     * @notice Gets the token address used by the factory
     * @return The address of the token
     */
    function token() external view returns (address);
}
