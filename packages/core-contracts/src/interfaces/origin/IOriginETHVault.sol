// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOriginETHVault {
    struct WithdrawalRequest {
        address withdrawer;
        bool claimed;
        uint40 timestamp; // timestamp of the withdrawal request
        // Amount of oTokens to redeem. eg OETH
        uint128 amount;
        // cumulative total of all withdrawal requests including this one.
        // this request can be claimed when this queued amount is less than or equal to the queue's claimable amount.
        uint128 queued;
    }

    function withdrawalRequests(
        uint256 requestId
    ) external view returns (WithdrawalRequest memory);
    function mint(address to, uint256 amount, uint256 minShares) external;
    function requestWithdrawal(
        uint256 amount
    ) external returns (uint256 requestId, uint256 queued);
    function claimWithdrawal(
        uint256 _requestId
    ) external returns (uint256 amount);
    function claimWithdrawals(
        uint256[] calldata _requestIds
    ) external returns (uint256[] memory amounts, uint256 totalAmount);
}
