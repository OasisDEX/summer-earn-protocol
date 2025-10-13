// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {Test} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {FleetCommanderRewardsManager} from "../../src/contracts/FleetCommanderRewardsManager.sol";

import {FleetCommanderRewardsManagerFactory} from "../../src/contracts/FleetCommanderRewardsManagerFactory.sol";
import {HarborCommand} from "../../src/contracts/HarborCommand.sol";
import {IFleetCommanderRewardsManager} from "../../src/interfaces/IFleetCommanderRewardsManager.sol";
import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestHelpers} from "../helpers/FleetCommanderTestHelpers.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {MockSummerGovernor} from "../mocks/MockSummerGovernor.sol";
import {MockSummerGovernor} from "../mocks/MockSummerGovernor.sol";
import {RestictedWithdrawalArkMock} from "../mocks/RestictedWithdrawalArkMock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
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
    HarborCommand public harborCommand;
    FleetCommanderRewardsManagerFactory
        public fleetCommanderRewardsManagerFactory;

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
    address public guardian = address(1);

    // Other variables
    string public fleetName = "OK_Fleet";
    FleetCommanderParams public fleetCommanderParams;

    // New variables
    IFleetCommanderRewardsManager public stakingRewardsManager;
    MockSummerGovernor public mockGovernor;
    ERC20Mock[] public rewardTokens;

    constructor() {}

    function initializeFleetCommanderWithMockArks(
        uint256 initialTipRate
    ) internal {
        mockToken = new ERC20Mock();
        // first setup the contracts
        setupBaseContracts();
        // then setup the mock arks - they are not initilaized with fleet commander address
        setupMockArks(address(mockToken));

        // setup the fleet commander - fleetcommander deploys buffer ark
        setupFleetCommanderWithBufferArk(
            address(mockToken),
            PercentageUtils.fromIntegerPercentage(initialTipRate)
        );
        // grant roles to the fleet commander - Dyanmic `COMMANDER_ROLE` to manage arks
        // grants governor keepr, curator roles

        address[] memory mockArks = new address[](4);
        mockArks[0] = ark1;
        mockArks[1] = ark2;
        mockArks[2] = ark3;
        mockArks[3] = ark4;
        grantRoles(mockArks, address(bufferArk), keeper);
        vm.startPrank(governor);
        fleetCommander.addArk(ark1);
        fleetCommander.addArk(ark2);
        fleetCommander.addArk(ark3);
        fleetCommander.addArk(ark4);
        vm.stopPrank();
        vm.label(address(mockArk1), "Ark1");
        vm.label(address(mockArk2), "Ark2");
        vm.label(address(mockArk3), "Ark3");
        vm.label(address(mockArk4), "Ark4-nonWithdrawable");

        FleetConfig memory config = fleetCommander.getConfig();
        stakingRewardsManager = IFleetCommanderRewardsManager(
            config.stakingRewardsManager
        );
    }

    function initializeFleetCommanderWithoutArks(
        address underlyingToken,
        uint256 initialTipRate
    ) internal {
        setupBaseContracts();
        setupFleetCommanderWithBufferArk(
            underlyingToken,
            PercentageUtils.fromIntegerPercentage(initialTipRate)
        );
    }

    function setupBaseContracts() internal {
        if (address(accessManager) == address(0)) {
            accessManager = new ProtocolAccessManager(governor);
        }
        if (address(harborCommand) == address(0)) {
            harborCommand = new HarborCommand(address(accessManager));
        }
        if (address(fleetCommanderRewardsManagerFactory) == address(0)) {
            fleetCommanderRewardsManagerFactory = new FleetCommanderRewardsManagerFactory();
        }
        if (address(configurationManager) == address(0)) {
            configurationManager = new ConfigurationManager(
                address(accessManager)
            );
            vm.prank(governor);
            configurationManager.initializeConfiguration(
                ConfigurationManagerParams({
                    raft: address(raft),
                    tipJar: address(tipJar),
                    treasury: treasury,
                    harborCommand: address(harborCommand),
                    fleetCommanderRewardsManagerFactory: address(
                        fleetCommanderRewardsManagerFactory
                    )
                })
            );
        }
    }

    function setupFleetCommanderWithBufferArk(
        address underlyingToken,
        Percentage initialTipRate
    ) internal {
        vm.startPrank(governor);
        // Setup StakingRewardsManager
        // Deploy mock governor if not already deployed
        if (address(mockGovernor) == address(0)) {
            mockGovernor = new MockSummerGovernor();
        }

        // Deploy reward tokens
        for (uint256 i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        // Prepare reward token addresses
        address[] memory rewardTokenAddresses = new address[](
            rewardTokens.length
        );
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokenAddresses[i] = address(rewardTokens[i]);
        }

        fleetCommanderParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: INITIAL_MINIMUM_FUNDS_BUFFER_BALANCE,
            initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
            asset: underlyingToken,
            name: fleetName,
            symbol: "TEST-SUM",
            details: "TestFleet-details",
            initialTipRate: initialTipRate,
            depositCap: type(uint256).max
        });
        fleetCommander = new FleetCommander(fleetCommanderParams);

        bufferArkAddress = fleetCommander.bufferArk();
        bufferArk = BufferArk(bufferArkAddress);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommander)
        );
        harborCommand.enlistFleetCommander(address(fleetCommander));
        vm.stopPrank();
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
                    details: "TestArk details",
                    accessManager: address(accessManager),
                    asset: tokenAddress,
                    configurationManager: address(configurationManager),
                    depositCap: depositCap,
                    maxRebalanceOutflow: type(uint256).max,
                    maxRebalanceInflow: type(uint256).max,
                    requiresKeeperData: requiresKeeperData,
                    maxDepositPercentageOfTVL: PERCENTAGE_100
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
                    details: "TestArk details",
                    accessManager: address(accessManager),
                    asset: tokenAddress,
                    configurationManager: address(configurationManager),
                    depositCap: depositCap,
                    maxRebalanceOutflow: type(uint256).max,
                    maxRebalanceInflow: type(uint256).max,
                    requiresKeeperData: requiresKeeperData,
                    maxDepositPercentageOfTVL: PERCENTAGE_100
                })
            );
    }
}
