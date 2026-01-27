// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IGainVault is IERC4626 {
    function reserveDeposit(address account, uint256 amountInETH) external;
    function gainAdapter() external view returns (address);
    function owner() external view returns (address);
    function loansDeployerAddress() external view returns (address);
    function scheduledCallerAddress() external view returns (address);
    function settlementAccount() external view returns (address);
    function pauseDepositsAndWithdrawals(
        bool bPauseDeposits,
        bool bPauseWithdrawals
    ) external;
    function processWithdrawal(address account, uint256 shares) external;
    function managementFeePercent() external view returns (uint256);
    function managementFeeLastKnownTimestamp() external view returns (uint256);
    function calculateManagementFee(
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (uint256);
    function updateIssuanceLimits(
        uint256 newMaxDepositAmount,
        uint256 newMaxWithdrawalAmount,
        uint256 newMaxTokenSupply
    ) external;
}
