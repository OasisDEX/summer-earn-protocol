// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @notice Configuration parameters for the ArkFactory contract
 *
 * @dev Used to prevent stack too deep error
 */
struct ArkFactoryParams {
    address governor;
    address raft;
    address aaveV3Pool;
}
