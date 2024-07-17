// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./CometStorage.sol";
import "./CometCore.sol";
import "./CometMainInterface.sol";
import "./CometExtInterface.sol";

abstract contract IComet is CometMainInterface, CometExtInterface {}

