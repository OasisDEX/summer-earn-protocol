// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface ISummerToken is IERC20 {
    struct TokenParams {
        string name;
        string symbol;
        address lzEndpoint;
        address governor;
    }
}
