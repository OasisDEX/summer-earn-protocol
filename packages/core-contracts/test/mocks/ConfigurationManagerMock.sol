// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";

abstract contract ConfigurationManagerMock is IConfigurationManager {
    address public tipJar;
    address public treasury;
    address public raft;
    uint256 public tipRate;
    address public harborCommand;

    constructor(
        address _tipJar,
        address _treasury,
        address _raft,
        address _harborCommand
    ) {
        tipJar = _tipJar;
        treasury = _treasury;
        raft = _raft;
        harborCommand = _harborCommand;
    }

    function initializeConfiguration(
        ConfigurationManagerParams memory params
    ) external {}

    function setRaft(address) external pure {}

    function setTipRate(uint8) external pure {}

    function setTreasury(address) external pure {}

    function setHarborCommand(address) external pure {}
}

contract ConfigurationManagerImplMock is ConfigurationManagerMock {
    constructor(
        address _tipJar,
        address _treasury,
        address _raft,
        address _harborCommand
    ) ConfigurationManagerMock(_tipJar, _treasury, _raft, _harborCommand) {}

    function setTipJar(address newTipJar) external override {
        tipJar = newTipJar;
    }

    function test_() public {}
}
