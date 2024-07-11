// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseArkParams} from "./ArkTypes.sol";

/**
 * @notice Ark configuration for use by Factory when cloning ark
 */
struct FactoryArkConfig {
    BaseArkParams baseArkParams;
    bytes specificArkParams;
    address arkImplementation; // Ark address
}
