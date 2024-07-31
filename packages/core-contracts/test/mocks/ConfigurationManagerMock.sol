// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

abstract contract ConfigurationManagerMock is IConfigurationManager {
    address public tipJar;

    constructor(address _tipJar) {
        tipJar = _tipJar;
    }

    function raft() external pure returns (address) {}

    function tipRate() external pure returns (uint8) {}

    function setRaft(address) external pure {}

    function setTipRate(uint8) external pure {}
}