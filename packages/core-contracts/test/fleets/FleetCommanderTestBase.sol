// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {PercentageUtils} from "../../src/libraries/PercentageUtils.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ArkMock, BaseArkParams} from "../mocks/ArkMock.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract FleetCommanderTestBase {
    using PercentageUtils for uint256;

    ConfigurationManager public configurationManager;
    IProtocolAccessManager public accessManager;
    FleetCommanderStorageWriter public fleetCommanderStorageWriter;
    FleetCommander public fleetCommanderImp;
    FleetCommander public fleetCommander;
    FleetCommanderParams public fleetCommanderParams;
    address public governor = address(1);
    address public raft = address(2);
    address public mockUser = address(3);
    address public keeper = address(4);

    address ark1 = address(10);
    address ark2 = address(11);
    address ark3 = address(12);

    address invalidArk = address(999);

    address[] initialArks;
    ERC20Mock public mockToken;
    ArkMock public mockArkImp;
    ArkMock public mockArk1;
    ArkMock public mockArk2;
    ArkMock public mockArk3;

    string public fleetName = "OK_Fleet";

    uint256 public BUFFER_BALANCE_SLOT;
    uint256 public MIN_BUFFER_BALANCE_SLOT;

    uint256 ark1_MAX_ALLOCATION = 10000 * 10 ** 6;
    uint256 ark2_MAX_ALLOCATION = 15000 * 10 ** 6;

    constructor() {
        mockToken = new ERC20Mock();

        accessManager = new ProtocolAccessManager(governor);

        IConfigurationManager configurationManagerImp = new ConfigurationManager();
        configurationManager = ConfigurationManager(
            Clones.clone(address(configurationManagerImp))
        );
        configurationManager.initialize(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: raft
            })
        );

        mockArkImp = new ArkMock();
        mockArk1 = ArkMock(Clones.clone(address(mockArkImp)));
        mockArk2 = ArkMock(Clones.clone(address(mockArkImp)));
        mockArk3 = ArkMock(Clones.clone(address(mockArkImp)));

        mockArk1.initialize(
            BaseArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager),
                maxAllocation: 10000 * 10 ** 6
            }),
            bytes("")
        );
        mockArk2.initialize(
            BaseArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager),
                maxAllocation: 10000 * 10 ** 6
            }),
            bytes("")
        );
        mockArk3.initialize(
            BaseArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager),
                maxAllocation: 10000 * 10 ** 6
            }),
            bytes("")
        );

        ark1 = address(mockArk1);
        ark2 = address(mockArk2);
        ark3 = address(mockArk3);

        initialArks = new address[](3);
        initialArks[0] = address(mockArk1);
        initialArks[1] = address(mockArk2);
        initialArks[2] = address(mockArk3);

        fleetCommanderParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumFundsBufferBalance: 10000 * 10 ** 6,
            initialRebalanceCooldown: 0,
            asset: address(mockToken),
            name: fleetName,
            symbol: string(abi.encodePacked(mockToken.symbol(), "-SUM")),
            initialMinimumPositionWithdrawal: PercentageUtils
                .fromDecimalPercentage(2),
            initialMaximumBufferWithdrawal: PercentageUtils
                .fromDecimalPercentage(20),
            depositCap: 100000000 * 10 ** 6
        });

        fleetCommanderImp = new FleetCommander();
    }
}
