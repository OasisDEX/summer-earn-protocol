// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IWithdrawalQueue {
    struct WithdrawalRequestStatus {
        /// @notice stETH token amount that was locked on withdrawal queue for this request
        uint256 amountOfStETH;
        /// @notice amount of stETH shares locked on withdrawal queue for this request
        uint256 amountOfShares;
        /// @notice address that can claim or transfer this request
        address owner;
        /// @notice timestamp of when the request was created, in seconds
        uint256 timestamp;
        /// @notice true, if request is finalized
        bool isFinalized;
        /// @notice true, if request is claimed. Request is claimable if (isFinalized && !isClaimed)
        bool isClaimed;
    }

    function requestWithdrawals(
        uint256[] memory amounts,
        address owner
    ) external returns (uint256[] memory _requestIds);
    function claimWithdrawals(
        uint256[] memory _requestIds,
        uint256[] memory _hints
    ) external;
    function claimWithdrawal(uint256 _requestId) external;
    function getWithdrawalRequests(
        address owner
    ) external view returns (uint256[] memory _requestIds);
    function getWithdrawalStatus(
        uint256[] memory _requestIds
    ) external view returns (WithdrawalRequestStatus[] memory _status);

    function finalize(
        uint256 _lastRequestIdToBeFinalized,
        uint256 _timestamp
    ) external;
}
