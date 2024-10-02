// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {SummerVestingWallet} from "../contracts/SummerVestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface ISummerToken is IERC20 {
    struct TokenParams {
        string name;
        string symbol;
        address lzEndpoint;
        address governor;
    }

    /**
     * @dev Creates a new vesting wallet for a beneficiary
     * @param beneficiary Address of the beneficiary to whom vested tokens are transferred
     * @param timeBasedAmount Amount of tokens to be vested
     * @param goal1Amount Amount of tokens to be vested
     * @param goal2Amount Amount of tokens to be vested
     * @param goal3Amount Amount of tokens to be vested
     * @param goal4Amount Amount of tokens to be vested
     * @param vestingType Type of vesting schedule. See VestingType for options.
     */
    function createVestingWallet(
        address beneficiary,
        uint256 timeBasedAmount,
        uint256 goal1Amount,
        uint256 goal2Amount,
        uint256 goal3Amount,
        uint256 goal4Amount,
        SummerVestingWallet.VestingType vestingType
    ) external;
}
