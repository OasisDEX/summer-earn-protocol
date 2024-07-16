// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @notice Swap params used by Raft contract
 */
struct SwapData {
    address fromAsset;
    uint256 amount;
    uint256 receiveAtLeast;
    bytes withData;
}
