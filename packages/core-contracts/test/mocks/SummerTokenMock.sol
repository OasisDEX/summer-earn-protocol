// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ISummerToken, SummerVestingWallet} from "@summerfi/earn-gov-contracts/interfaces/ISummerToken.sol";

contract MockSummerToken is ERC20, ERC20Burnable, ISummerToken {
    uint256 private constant INITIAL_SUPPLY = 1e9;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, INITIAL_SUPPLY * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function createVestingWallet(
        address beneficiary,
        uint256 amount,
        SummerVestingWallet.VestingType vestingType
    ) external {
        revert("Not implemented");
    }
}
