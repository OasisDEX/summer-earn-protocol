// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IWithdrawalQueue
/// @notice Interface for Lido's stETH withdrawal queue
interface IWithdrawalQueue {
    /// @notice Status of a withdrawal request in the queue
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

    /// @notice Requests withdrawals of stETH, creating one queued request per amount
    /// @param amounts The stETH amounts to withdraw, one per request
    /// @param owner The address that can claim the resulting requests
    /// @return _requestIds The ids of the created withdrawal requests
    function requestWithdrawals(
        uint256[] memory amounts,
        address owner
    ) external returns (uint256[] memory _requestIds);
    /// @notice Claims multiple finalized withdrawal requests
    /// @param _requestIds The ids of the requests to claim
    /// @param _hints Hints locating each request's finalization checkpoint
    function claimWithdrawals(
        uint256[] memory _requestIds,
        uint256[] memory _hints
    ) external;
    /// @notice Claims a single finalized withdrawal request
    /// @param _requestId The id of the request to claim
    function claimWithdrawal(uint256 _requestId) external;
    /// @notice Returns the ids of all withdrawal requests owned by an account
    /// @param owner The account to query
    /// @return _requestIds The owner's withdrawal request ids
    function getWithdrawalRequests(
        address owner
    ) external view returns (uint256[] memory _requestIds);
    /// @notice Returns the status of the given withdrawal requests
    /// @param _requestIds The request ids to query
    /// @return _status The status of each requested withdrawal
    function getWithdrawalStatus(
        uint256[] memory _requestIds
    ) external view returns (WithdrawalRequestStatus[] memory _status);

    /// @notice Finalizes withdrawal requests up to a given id
    /// @param _lastRequestIdToBeFinalized The highest request id to finalize
    /// @param _timestamp The finalization timestamp
    function finalize(
        uint256 _lastRequestIdToBeFinalized,
        uint256 _timestamp
    ) external;
}
