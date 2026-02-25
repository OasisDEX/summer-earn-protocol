// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISyrupWithdrawalManagerV2 {
    struct WithdrawalRequest {
        address owner;
        uint256 shares;
    }

    function requestIds(address owner_) external view returns (uint256);

    function requests(
        uint256 requestId_
    ) external view returns (WithdrawalRequest memory);

    function userEscrowedShares(address owner_) external view returns (uint256);
}
