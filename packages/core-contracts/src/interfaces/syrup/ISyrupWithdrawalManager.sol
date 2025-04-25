// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISyrupWithdrawalManager {
    struct WithdrawalRequest {
        address owner;
        uint256 shares;
    }

    function requestIds(address owner_) external view returns (uint128);

    function requests(
        uint128 requestId_
    ) external view returns (WithdrawalRequest memory);
}
