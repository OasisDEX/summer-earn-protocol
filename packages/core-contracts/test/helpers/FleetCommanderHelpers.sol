// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {PercentageUtils} from "../../src/libraries/PercentageUtils.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkConfiguration, FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {FleetCommanderStorageWriter} from "./FleetCommanderStorageWriter.sol";

abstract contract FleetCommanderHelpers {
    using PercentageUtils for uint256;

    IProtocolAccessManager public accessManager;
    FleetCommanderStorageWriter public fleetCommanderStorageWriter;
    FleetCommander public fleetCommander;
    FleetCommanderParams public defaultFleetCommanderParams;
    address public governor = address(1);
    address public raft = address(2);
    address public mockUser = address(3);
    address public keeper = address(4);

    address ark1 = address(10);
    address ark2 = address(11);
    address ark3 = address(12);

    address invalidArk = address(999);

    ERC20Mock public mockToken;
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

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: raft
            })
        );

        // Instantiate ArkMock contracts for ark1 and ark2
        mockArk1 = new ArkMock(
            ArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        mockArk2 = new ArkMock(
            ArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        mockArk3 = new ArkMock(
            ArkParams({
                accessManager: address(accessManager),
                token: address(mockToken),
                configurationManager: address(configurationManager)
            })
        );

        ark1 = address(mockArk1);
        ark2 = address(mockArk2);
        ark3 = address(mockArk3);

        ArkConfiguration[] memory initialArks = new ArkConfiguration[](3);
        initialArks[0] = ArkConfiguration({
            ark: ark1,
            maxAllocation: ark1_MAX_ALLOCATION
        });
        initialArks[1] = ArkConfiguration({
            ark: ark2,
            maxAllocation: ark2_MAX_ALLOCATION
        });
        initialArks[2] = ArkConfiguration({
            ark: ark3,
            maxAllocation: 10000 * 10 ** 6
        });
        defaultFleetCommanderParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialArks: initialArks,
            initialMinimumFundsBufferBalance: 10000 * 10 ** 6,
            initialRebalanceCooldown: 0,
            asset: address(mockToken),
            name: fleetName,
            symbol: string(abi.encodePacked(mockToken.symbol(), "-SUM")),
            initialMinimumPositionWithdrawal: PercentageUtils
                .fromDecimalPercentage(2),
            initialMaximumBufferWithdrawal: PercentageUtils
                .fromDecimalPercentage(20)
        });
    }
}
