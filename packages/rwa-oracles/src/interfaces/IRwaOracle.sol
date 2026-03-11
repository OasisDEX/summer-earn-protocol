// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRwaOracleErrors} from "./IRwaOracleErrors.sol";
import {IRwaOracleEvents} from "./IRwaOracleEvents.sol";

interface IRwaOracle is IRwaOracleErrors, IRwaOracleEvents {
    function updatePrice(
        int256 price,
        uint256 timestamp,
        bytes[] calldata signatures
    ) external;
    function addSigner(address signer) external;
    function removeSigner(address signer) external;
    function setThreshold(uint256 threshold) external;
}
