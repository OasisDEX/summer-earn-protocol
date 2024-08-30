// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestHelpers} from "../helpers/FleetCommanderTestHelpers.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

abstract contract FleetCommanderTestBase is Test, FleetCommanderTestHelpers {
    using PercentageUtils for uint256;

    uint256 public BUFFER_BALANCE_SLOT;
    uint256 public MIN_BUFFER_BALANCE_SLOT;

    // Constants
    uint256 constant INITIAL_REBALANCE_COOLDOWN = 1000;
    uint256 constant INITIAL_MINIMUM_FUNDS_BUFFER_BALANCE = 10000 * 10 ** 6;
    uint256 constant ARK1_MAX_ALLOCATION = 10000 * 10 ** 6;
    uint256 constant ARK2_MAX_ALLOCATION = 15000 * 10 ** 6;
    uint256 constant ARK3_MAX_ALLOCATION = 20000 * 10 ** 6;
    uint256 constant ARK4_MAX_ALLOCATION = 25000 * 10 ** 6;

    // Contracts
    IProtocolAccessManager public accessManager;
    IConfigurationManager public configurationManager;
    FleetCommanderStorageWriter public fleetCommanderStorageWriter;
    FleetCommander public fleetCommander;
    ERC20Mock public mockToken;
    ArkMock public mockArk1;
    ArkMock public mockArk2;
    ArkMock public mockArk3;
    ArkMock public mockArk4;
    BufferArk public bufferArk;

    // Addresses
    address public governor = address(1);
    address public raft = address(2);
    address public mockUser = address(3);
    address public mockUser2 = address(5);
    address public keeper = address(4);
    address public tipJar = address(6);
    address public ark1 = address(10);
    address public ark2 = address(11);
    address public ark3 = address(12);
    address public ark4 = address(14);
    address public bufferArkAddress = address(13);
    address public invalidArk = address(999);
    address public nonOwner = address(0xdeadbeef);

    // Other variables
    string public fleetName = "OK_Fleet";
    FleetCommanderParams public fleetCommanderParams;

    constructor() {}

    function initializeFleetCommanderWithMockArks(
        uint256 initialTipRate
    ) internal {
        mockToken = new ERC20Mock();
        setupBaseContracts(address(mockToken));
        setupMockArks(address(mockToken));
        address[] memory initialArks = new address[](4);
        initialArks[0] = ark1;
        initialArks[1] = ark2;
        initialArks[2] = ark3;
        initialArks[3] = ark4;
        setupFleetCommander(
            address(mockToken),
            initialArks,
            PercentageUtils.fromIntegerPercentage(initialTipRate)
        );
        grantRoles(initialArks, address(bufferArk), keeper);
        vm.label(address(mockArk1), "Ark1");
        vm.label(address(mockArk2), "Ark2");
        vm.label(address(mockArk3), "Ark3");
        vm.label(address(mockArk4), "Ark4-nonWithdrawable");
    }

    function initializeFleetCommanderWithoutArks(
        address underlyingToken,
        uint256 initialTipRate
    ) internal {
        setupBaseContracts(underlyingToken);
        setupFleetCommander(
            underlyingToken,
            new address[](0),
            PercentageUtils.fromIntegerPercentage(initialTipRate)
        );
    }

    function setupBaseContracts(address underlyingToken) internal {
        if (address(accessManager) == address(0)) {
            accessManager = new ProtocolAccessManager(governor);
        }
        if (address(configurationManager) == address(0)) {
            configurationManager = new ConfigurationManager(
                ConfigurationManagerParams({
                    accessManager: address(accessManager),
                    tipJar: tipJar,
                    raft: raft
                })
            );
        }
        bufferArk = new BufferArk(
            ArkParams({
                name: "TestArk",
                accessManager: address(accessManager),
                token: underlyingToken,
                configurationManager: address(configurationManager),
                depositCap: type(uint256).max,
                maxRebalanceOutflow: type(uint256).max,
                maxRebalanceInflow: type(uint256).max,
                unrestrictedWithdrawal: true
            })
        );
        bufferArkAddress = address(bufferArk);
    }

    function setupFleetCommander(
        address underlyingToken,
        address[] memory initialArks,
        Percentage initialTipRate
    ) internal {
        fleetCommanderParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialArks: initialArks,
            initialMinimumBufferBalance: INITIAL_MINIMUM_FUNDS_BUFFER_BALANCE,
            initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
            asset: underlyingToken,
            name: fleetName,
            symbol: "TEST-SUM",
            initialTipRate: initialTipRate,
            depositCap: type(uint256).max,
            bufferArk: bufferArkAddress
        });
        fleetCommander = new FleetCommander(fleetCommanderParams);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommander)
        );
    }

    function setupMockArks(address underlyingToken) internal {
        mockArk1 = createMockArk(underlyingToken, ARK1_MAX_ALLOCATION, true);
        mockArk2 = createMockArk(underlyingToken, ARK2_MAX_ALLOCATION, true);
        mockArk3 = createMockArk(underlyingToken, ARK3_MAX_ALLOCATION, true);
        mockArk4 = createMockArk(underlyingToken, ARK4_MAX_ALLOCATION, false);
        ark1 = address(mockArk1);
        ark2 = address(mockArk2);
        ark3 = address(mockArk3);
        ark4 = address(mockArk4);
    }

    function grantRoles(
        address[] memory arks,
        address _bufferArkAddress,
        address _keeper
    ) internal {
        vm.startPrank(governor);
        accessManager.grantKeeperRole(_keeper);
        BufferArk(_bufferArkAddress).grantCommanderRole(
            address(fleetCommander)
        );
        for (uint256 i = 0; i < arks.length; i++) {
            ArkMock(arks[i]).grantCommanderRole(address(fleetCommander));
        }
        vm.stopPrank();
    }

    function createMockArk(
        address tokenAddress,
        uint256 depositCap,
        bool unrestrictedWithdrawal
    ) internal returns (ArkMock) {
        return
            new ArkMock(
                ArkParams({
                    name: "TestArk",
                    accessManager: address(accessManager),
                    token: tokenAddress,
                    configurationManager: address(configurationManager),
                    depositCap: depositCap,
                    maxRebalanceOutflow: type(uint256).max,
                    maxRebalanceInflow: type(uint256).max,
                    unrestrictedWithdrawal: unrestrictedWithdrawal
                })
            );
    }
}
