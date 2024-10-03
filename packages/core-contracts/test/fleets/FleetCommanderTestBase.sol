// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {Test} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ContractSpecificRoles} from "../../src/interfaces/IProtocolAccessManager.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestHelpers} from "../helpers/FleetCommanderTestHelpers.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {RestictedWithdrawalArkMock} from "../mocks/RestictedWithdrawalArkMock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {console} from "forge-std/console.sol";

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
    RestictedWithdrawalArkMock public mockArk4;
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
    address public treasury = address(777);
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
        address[] memory mockArks = new address[](4);
        mockArks[0] = ark1;
        mockArks[1] = ark2;
        mockArks[2] = ark3;
        mockArks[3] = ark4;
        setupFleetCommander(
            address(mockToken),
            PercentageUtils.fromIntegerPercentage(initialTipRate)
        );
        grantRoles(mockArks, address(bufferArk), keeper);
        vm.prank(governor);
        fleetCommander.addArks(mockArks);
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
            PercentageUtils.fromIntegerPercentage(initialTipRate)
        );
    }

    function setupBaseContracts(address underlyingToken) internal {
        if (address(accessManager) == address(0)) {
            accessManager = new ProtocolAccessManager(governor);
        }
        if (address(configurationManager) == address(0)) {
            configurationManager = new ConfigurationManager(
                address(accessManager)
            );
            vm.prank(governor);
            configurationManager.initialize(
                ConfigurationManagerParams({
                    raft: address(raft),
                    tipJar: address(tipJar),
                    treasury: treasury
                })
            );
        }
    }

    function setupFleetCommander(
        address underlyingToken,
        Percentage initialTipRate
    ) internal {
        fleetCommanderParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: INITIAL_MINIMUM_FUNDS_BUFFER_BALANCE,
            initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
            asset: underlyingToken,
            name: fleetName,
            symbol: "TEST-SUM",
            initialTipRate: initialTipRate,
            depositCap: type(uint256).max
        });
        fleetCommander = new FleetCommander(fleetCommanderParams);
        bufferArkAddress = fleetCommander.bufferArk();
        bufferArk = BufferArk(bufferArkAddress);
        console.log("bufferArkAddress in test base", bufferArkAddress);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommander)
        );
    }

    function setupMockArks(address underlyingToken) internal {
        mockArk1 = createMockArk(underlyingToken, ARK1_MAX_ALLOCATION, false);
        mockArk2 = createMockArk(underlyingToken, ARK2_MAX_ALLOCATION, false);
        mockArk3 = createMockArk(underlyingToken, ARK3_MAX_ALLOCATION, false);
        mockArk4 = createRestictedWithdrawalArkMock(
            underlyingToken,
            ARK4_MAX_ALLOCATION,
            true
        );
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
        accessManager.grantKeeperRole(address(fleetCommander), _keeper);
        accessManager.grantCuratorRole(address(fleetCommander), governor);
        accessManager.grantCommanderRole(
            address(_bufferArkAddress),
            address(fleetCommander)
        );
        for (uint256 i = 0; i < arks.length; i++) {
            accessManager.grantCommanderRole(arks[i], address(fleetCommander));
        }
        vm.stopPrank();
    }

    function createMockArk(
        address tokenAddress,
        uint256 depositCap,
        bool requiresKeeperData
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
                    requiresKeeperData: requiresKeeperData
                })
            );
    }

    function createRestictedWithdrawalArkMock(
        address tokenAddress,
        uint256 depositCap,
        bool requiresKeeperData
    ) internal returns (RestictedWithdrawalArkMock) {
        return
            new RestictedWithdrawalArkMock(
                ArkParams({
                    name: "TestArk",
                    accessManager: address(accessManager),
                    token: tokenAddress,
                    configurationManager: address(configurationManager),
                    depositCap: depositCap,
                    maxRebalanceOutflow: type(uint256).max,
                    maxRebalanceInflow: type(uint256).max,
                    requiresKeeperData: requiresKeeperData
                })
            );
    }
}
