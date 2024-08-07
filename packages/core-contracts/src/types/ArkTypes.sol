// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @notice Configuration parameters for the Ark contract
 */
struct ArkParams {
    string name;
    address accessManager;
    address configurationManager;
    address token;
    uint256 maxAllocation;
}
