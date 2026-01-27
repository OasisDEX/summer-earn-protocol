// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IMinimalVestingFactory} from "../../src/interfaces/IMinimalVestingFactory.sol";
import {IMinimalVestingWallet} from "../../src/interfaces/IMinimalVestingWallet.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/*
 * @title SummerVestingWalletsEscrow Vesting Tests
 * @dev Test contract for SummerVestingWalletsEscrow contract vesting functionality.
 */

// Mock Vesting Factory for testing
contract TestMockVestingFactory is IMinimalVestingFactory {
    mapping(address => address) public vestingWallets;
    mapping(address => address) public vestingWalletOwners;

    function setVestingWallet(address user, address wallet) external {
        address previousOwner = vestingWalletOwners[wallet];
        vestingWallets[previousOwner] = address(0);
        vestingWallets[user] = wallet;
        vestingWalletOwners[wallet] = user;
    }

    function removeVestingWallet(address user) external {
        address wallet = vestingWallets[user];
        if (wallet != address(0)) {
            vestingWalletOwners[wallet] = address(0);
            vestingWallets[user] = address(0);
        }
    }
}

// Mock Vesting Wallet for testing
contract TestMockVestingWallet is IMinimalVestingWallet {
    address public owner;
    MockERC20 public token;

    constructor(address _owner, address _token) {
        owner = _owner;
        token = MockERC20(_token);
    }

    function balanceOf(address) external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner can transfer");
        owner = newOwner;
    }

    function released(address) external pure returns (uint256) {
        return 0;
    }
}
