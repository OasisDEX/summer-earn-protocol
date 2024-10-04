// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {AaveV3Ark, ArkParams} from "../../src/contracts/arks/AaveV3Ark.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IFleetCommander} from "../../src/interfaces/IFleetCommander.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";

import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

import {TestHelpers} from "../helpers/TestHelpers.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {RestictedWithdrawalArkMock} from "../mocks/RestictedWithdrawalArkMock.sol";
import {HarborCommand} from "../../src/contracts/HarborCommand.sol";

contract ArkTestBase is TestHelpers {
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    address public tipJar = address(3);
    address public treasury = address(5);
    ERC20Mock public mockToken;

    ProtocolAccessManager public accessManager;
    ConfigurationManager public configurationManager;
    HarborCommand public harborCommand;

    function initializeCoreContracts() internal {
        mockToken = new ERC20Mock();
        if (address(accessManager) == address(0)) {
            accessManager = new ProtocolAccessManager(governor);
        }
        if (address(harborCommand) == address(0)) {
            harborCommand = new HarborCommand(address(accessManager));
        }
        if (address(configurationManager) == address(0)) {
            configurationManager = new ConfigurationManager(
                address(accessManager)
            );
            vm.prank(governor);
            configurationManager.initializeConfiguration(
                ConfigurationManagerParams({
                    tipJar: tipJar,
                    raft: raft,
                    treasury: treasury,
                    harborCommand: address(harborCommand)
                })
            );
        }
    }
}
