// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISummerVestingWalletFactory} from "../interfaces/ISummerVestingWalletFactory.sol";
import {SummerVestingWallet} from "../contracts/SummerVestingWallet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title SummerVestingWalletFactory
 * @notice Factory contract for creating new SummerVestingWallet instances
 * @dev Creates and tracks vesting wallets for beneficiaries with both time-based and goal-based vesting
 */
contract SummerVestingWalletFactory is
    ISummerVestingWalletFactory,
    ProtocolAccessManaged
{
    /** @notice The ERC20 token that will be vested */
    address public immutable token;

    /** @notice Mapping from beneficiary address to their vesting wallet address */
    mapping(address beneficiary => address vestingWallet) public vestingWallets;
    /** @notice Mapping from vesting wallet address to its beneficiary address */
    mapping(address vestingWallet => address beneficiary)
        public vestingWalletOwners;

    /**
     * @notice Initializes the factory with the token to be vested
     * @param _token The address of the ERC20 token that will be vested
     * @param _accessManager The address of the ProtocolAccessManager contract
     */
    constructor(
        address _token,
        address _accessManager
    ) ProtocolAccessManaged(_accessManager) {
        token = _token;
    }

    /**
     * @notice Creates a new vesting wallet for a beneficiary
     * @dev Only callable by the Foundation
     */
    function createVestingWallet(
        address beneficiary,
        uint256 timeBasedAmount,
        uint256[] memory goalAmounts,
        SummerVestingWallet.VestingType vestingType
    ) external onlyFoundation returns (address newVestingWallet) {
        if (vestingWallets[beneficiary] != address(0)) {
            revert VestingWalletAlreadyExists(beneficiary);
        }

        uint64 startTimestamp = uint64(block.timestamp);
        uint64 durationSeconds = 730 days; // 2 years for both vesting types

        uint256 totalAmount = timeBasedAmount;
        for (uint256 i = 0; i < goalAmounts.length; i++) {
            totalAmount += goalAmounts[i];
        }

        newVestingWallet = address(
            new SummerVestingWallet(
                token,
                beneficiary,
                startTimestamp,
                durationSeconds,
                vestingType,
                timeBasedAmount,
                goalAmounts,
                address(_accessManager) // Pass access manager instead of admin
            )
        );

        vestingWallets[beneficiary] = newVestingWallet;
        vestingWalletOwners[newVestingWallet] = beneficiary;

        // Transfer tokens from sender to the new vesting wallet
        IERC20(token).transferFrom(msg.sender, newVestingWallet, totalAmount);

        emit VestingWalletCreated(
            beneficiary,
            newVestingWallet,
            timeBasedAmount,
            goalAmounts,
            vestingType
        );
    }
}
