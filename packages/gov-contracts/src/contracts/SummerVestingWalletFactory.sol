// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISummerVestingWalletFactory} from "../interfaces/ISummerVestingWalletFactory.sol";
import {SummerVestingWallet} from "../contracts/SummerVestingWallet.sol";

contract SummerVestingWalletFactory is ISummerVestingWalletFactory {
    address public immutable token;

    mapping(address => address) public vestingWallets;
    mapping(address => address) public vestingWalletOwners;

    constructor(address _token) {
        token = _token;
    }

    function createVestingWallet(
        address beneficiary,
        uint256 timeBasedAmount,
        uint256[] memory goalAmounts,
        SummerVestingWallet.VestingType vestingType
    ) external returns (address newVestingWallet) {
        if (vestingWallets[beneficiary] != address(0)) {
            revert VestingWalletAlreadyExists(beneficiary);
        }

        uint64 startTimestamp = uint64(block.timestamp);

        uint256 totalAmount = timeBasedAmount;
        for (uint256 i = 0; i < goalAmounts.length; i++) {
            totalAmount += goalAmounts[i];
        }

        newVestingWallet = address(
            new SummerVestingWallet(
                token,
                beneficiary,
                startTimestamp,
                vestingType,
                timeBasedAmount,
                goalAmounts,
                msg.sender // admin is the caller
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
