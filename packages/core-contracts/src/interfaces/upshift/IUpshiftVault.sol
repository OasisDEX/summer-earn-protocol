// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IUpshiftVault is IERC4626 {
    function requestRedeem(
        uint256 shares,
        address receiverAddr,
        address holderAddr
    ) external returns (uint256 assets, uint256 claimableEpoch);

    function claim(
        uint256 year,
        uint256 month,
        uint256 day,
        address receiverAddr
    ) external returns (uint256, uint256);

    function getWithdrawalEpoch()
        external
        view
        returns (
            uint256 year,
            uint256 month,
            uint256 day,
            uint256 claimableEpoch
        );

    function getClaimableAmountByReceiver(
        uint256 year,
        uint256 month,
        uint256 day,
        address receiverAddr
    ) external view returns (uint256);

    function getScheduledTransactionsByDate(
        uint256 year,
        uint256 month,
        uint256 day
    ) external view returns (uint256 totalTransactions, uint256 executionEpoch);

    function processAllClaimsByDate(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 limit
    ) external;

    function lagDuration() external view returns (uint256);
}
