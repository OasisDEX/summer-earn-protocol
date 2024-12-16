// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerVestingWallet} from "./ISummerVestingWallet.sol";

interface ISummerVestingWalletFactory {
    /** @notice Custom errors */
    error ZeroTokenAddress();
    error InsufficientAllowance(uint256 required, uint256 actual);
    error InsufficientBalance(uint256 required, uint256 actual);
    error TransferAmountMismatch(uint256 expected, uint256 actual);
    error VestingWalletAlreadyExists(address beneficiary);

    /**
     * @notice Emitted when a new vesting wallet is created
     * @param beneficiary The address of the beneficiary
     * @param vestingWallet The address of the created vesting wallet
     * @param timeBasedAmount The amount of tokens to be vested based on time
     * @param goalAmounts The amounts of tokens to be vested based on goals
     * @param vestingType The type of vesting schedule
     */
    event VestingWalletCreated(
        address indexed beneficiary,
        address indexed vestingWallet,
        uint256 timeBasedAmount,
        uint256[] goalAmounts,
        ISummerVestingWallet.VestingType vestingType
    );

    /**
     * @notice Creates a new vesting wallet for a beneficiary
     * @param beneficiary Address of the beneficiary to whom vested tokens are transferred
     * @param timeBasedAmount Amount of tokens to be vested based on time
     * @param goalAmounts Array of token amounts to be vested based on performance goals
     * @param vestingType Type of vesting schedule
     * @return newVestingWallet The address of the created vesting wallet
     */
    function createVestingWallet(
        address beneficiary,
        uint256 timeBasedAmount,
        uint256[] memory goalAmounts,
        ISummerVestingWallet.VestingType vestingType
    ) external returns (address newVestingWallet);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the vesting wallet address for a given account
     * @param owner The address of the account
     * @return The address of the vesting wallet
     */
    function vestingWallets(address owner) external view returns (address);

    /**
     * @notice Gets the owner of a vesting wallet for a given account
     * @param beneficiary The address of the vesting wallet
     * @return The address of the owner
     */
    function vestingWalletOwners(
        address beneficiary
    ) external view returns (address);
}
