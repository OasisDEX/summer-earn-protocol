// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

abstract contract ConfigurationManagerMock is IConfigurationManager {
    address public tipJar;
    address public treasury;

    constructor(address _tipJar, address _treasury) {
        tipJar = _tipJar;
        treasury = _treasury;
    }

    function raft() external pure returns (address) {}

    function tipRate() external pure returns (uint256) {}

    function setRaft(address) external pure {}

    function setTipRate(uint8) external pure {}

    function setTreasury(address) external pure {}
}
