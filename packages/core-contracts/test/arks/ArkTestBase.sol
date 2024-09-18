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

import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {RestictedWithdrawalArkMock} from "../mocks/RestictedWithdrawalArkMock.sol";

contract ArkTestBase {
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    address public tipJar = address(3);
    address public treasury = address(5);
    ERC20Mock public mockToken;

    ProtocolAccessManager public accessManager;
    ConfigurationManager public configurationManager;

    function initializeCoreContracts() internal {
        mockToken = new ERC20Mock();
        if (address(accessManager) == address(0)) {
            accessManager = new ProtocolAccessManager(governor);
        }
        if (address(configurationManager) == address(0)) {
            configurationManager = new ConfigurationManager(
                ConfigurationManagerParams({
                    accessManager: address(accessManager),
                    tipJar: tipJar,
                    raft: raft,
                    treasury: treasury
                })
            );
        }
    }
}
