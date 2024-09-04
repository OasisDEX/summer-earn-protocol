// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SummerToken is ERC20, ERC20Burnable {
    constructor() ERC20("SummerToken", "SUMMER") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}
