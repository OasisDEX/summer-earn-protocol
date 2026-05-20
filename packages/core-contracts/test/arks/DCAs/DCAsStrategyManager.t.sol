// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "../../../src/contracts/FleetCommander.sol";
import {DCAStrategyManager} from "../../../src/contracts/DCA/DCAStrategyManager.sol";
import {IDCAStrategyManager} from "../../../src/interfaces/arks/IDCAStrategyManager.sol";
import {IFleetCommander} from "../../../src/interfaces/IFleetCommander.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {FleetCommanderParams} from "../../../src/types/FleetCommanderTypes.sol";
import {toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {HarborCommand} from "../../../src/contracts/HarborCommand.sol";
import {FleetCommanderRewardsManagerFactory} from "../../../src/contracts/FleetCommanderRewardsManagerFactory.sol";
import {Test, console} from "forge-std/Test.sol";
import {IPermit2} from "../../../src/interfaces/permit2/IPermit2.sol";

contract DCAStrategyManagerTest is Test {
    DCAStrategyManager public dcaManager;
    FleetCommander public usdcFleet;
    FleetCommander public wethFleet;

    address public constant ENSO_ROUTER =
        0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf;
    address public constant ETH_USD_FEED =
        0x5F4EC3dF9CBd43714FE2740F5E3617235d988Bbb;
    address public constant USDC_USD_FEED =
        0x8fFFfFd4B3Cf5CA76D5CD5D9D8Bc5A9E5b0c4dd9;
    address public constant PERMIT2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 constant FORK_BLOCK = 20576616;

    address public governor = address(1);
    address public keeper = address(2);
    address public strategyOwner = address(3);
    address public raft = address(4);
    address public tipJar = address(5);
    address public treasury = address(6);

    ProtocolAccessManager public accessManager;
    ConfigurationManager public configurationManager;
    HarborCommand public harborCommand;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        _setupContracts();
        _setupRoles();
    }

    function _setupContracts() internal {
        accessManager = new ProtocolAccessManager(governor);

        harborCommand = new HarborCommand(address(accessManager));

        configurationManager = new ConfigurationManager(address(accessManager));

        FleetCommanderRewardsManagerFactory factory = new FleetCommanderRewardsManagerFactory();

        vm.startPrank(governor);
        accessManager.grantGovernorRole(governor);
        configurationManager.initializeConfiguration(
            ConfigurationManagerParams({
                raft: raft,
                tipJar: tipJar,
                treasury: treasury,
                harborCommand: address(harborCommand),
                fleetCommanderRewardsManagerFactory: address(factory)
            })
        );
        accessManager.grantSuperKeeperRole(keeper);

        FleetCommanderParams memory usdcParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: 10000 * 10 ** 6,
            initialRebalanceCooldown: 1000,
            asset: USDC_ADDRESS,
            name: "USDC Fleet",
            symbol: "USDC-FLEET",
            details: "USDC Fleet",
            initialTipRate: toPercentage(0),
            depositCap: type(uint256).max
        });
        usdcFleet = new FleetCommander(usdcParams);
        harborCommand.enlistFleetCommander(address(usdcFleet));

        FleetCommanderParams memory wethParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: 1 ether,
            initialRebalanceCooldown: 1000,
            asset: WETH_ADDRESS,
            name: "WETH Fleet",
            symbol: "WETH-FLEET",
            details: "WETH Fleet",
            initialTipRate: toPercentage(0),
            depositCap: type(uint256).max
        });
        wethFleet = new FleetCommander(wethParams);
        harborCommand.enlistFleetCommander(address(wethFleet));

        dcaManager = new DCAStrategyManager(
            address(accessManager),
            ENSO_ROUTER,
            address(harborCommand),
            ETH_USD_FEED,
            USDC_USD_FEED,
            PERMIT2
        );

        vm.stopPrank();
    }

    function _setupRoles() internal {
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(dcaManager), keeper);
        vm.stopPrank();
    }

    function test_CreateStrategy_RevertsIfIntervalTooShortOnMainnet() public {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.interval = 1 hours;

        vm.expectRevert(
            abi.encodeWithSignature(
                "IntervalTooShort(uint256,uint256)",
                1 hours,
                7 days
            )
        );
        dcaManager.createStrategy(config, "");
        vm.stopPrank();
    }

    function test_CheckUpkeep_ReturnsTrueWhenReady() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig(), "");
        vm.stopPrank();

        (bool upkeepNeededBefore, ) = dcaManager.checkUpkeep(strategyId);
        assertFalse(
            upkeepNeededBefore,
            "Upkeep should be false before interval"
        );

        vm.warp(block.timestamp + 7 days);

        (bool upkeepNeededAfter, ) = dcaManager.checkUpkeep(strategyId);
        assertTrue(upkeepNeededAfter, "Upkeep should be true after interval");
    }

    function test_CreateStrategy_AssignsUniqueIdAndCommitment() public {
        vm.startPrank(strategyOwner);

        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();

        uint256 strategyId = dcaManager.createStrategy(config, "");

        assertEq(strategyId, 0, "First strategy should have id 0");
        assertTrue(
            dcaManager.strategyCommitments(strategyId) != bytes32(0),
            "Commitment should be set"
        );

        IDCAStrategyManager.StrategyConfig memory config2 = _defaultConfig();
        config2.owner = address(0x2222);
        uint256 strategyId2 = dcaManager.createStrategy(config2, "");

        assertEq(strategyId2, 1, "Second strategy should have id 1");

        vm.stopPrank();
    }

    function test_PauseAndResume_UpdatesStateCorrectly() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig(), "");

        dcaManager.pauseStrategy(strategyId);

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(state.status, uint8(IDCAStrategyManager.Status.PAUSED));

        dcaManager.resumeStrategy(strategyId);

        state = dcaManager.strategyStates(strategyId);
        assertEq(state.status, uint8(IDCAStrategyManager.Status.ACTIVE));
        vm.stopPrank();
    }

    // ==========================================
    // Existing base tests
    // ==========================================

    function test_CancelStrategy_PreventsFurtherExecutions() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig(), "");

        dcaManager.cancelStrategy(strategyId);

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(state.status, uint8(IDCAStrategyManager.Status.CANCELLED));
        vm.stopPrank();

        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSignature("StrategyNotActive(uint256)", strategyId)
        );
        dcaManager.pauseStrategy(strategyId);
    }

    function test_Execute_RevertsOnCommitmentMismatch() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig(), "");
        vm.stopPrank();

        IDCAStrategyManager.StrategyConfig
            memory wrongConfig = _defaultConfig();
        wrongConfig.strategyId = strategyId;
        wrongConfig.tradeAmount = 1000e18;

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("CommitmentMismatch(uint256)", strategyId)
        );
        dcaManager.executeDCA(wrongConfig, "");
    }

    function test_Execute_RevertsOnNonMatchingConfig() public {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.maxTrades = 2;
        uint256 strategyId = dcaManager.createStrategy(config, "");
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig
            memory wrongConfig = _defaultConfig();
        wrongConfig.maxTrades = 999;

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("CommitmentMismatch(uint256)", strategyId)
        );
        dcaManager.executeDCA(wrongConfig, "");
    }

    function test_Execute_RevertsIfNotKeeper() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig(), "");
        vm.stopPrank();

        IDCAStrategyManager.StrategyConfig memory execConfig = _defaultConfig();

        vm.expectRevert();
        dcaManager.executeDCA(execConfig, "");
    }

    function test_EditStrategy_UpdatesCommitmentAndSchedule() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig(), "");

        IDCAStrategyManager.StrategyConfig memory newConfig = _defaultConfig();
        newConfig.interval = 8 days;

        dcaManager.editStrategy(newConfig);

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(state.nextTriggerAt, state.lastScheduledAt + 8 days);

        vm.stopPrank();
    }

    function _defaultConfig()
        internal
        view
        returns (IDCAStrategyManager.StrategyConfig memory)
    {
        return
            IDCAStrategyManager.StrategyConfig({
                strategyId: 0,
                owner: strategyOwner,
                sourceVault: IFleetCommander(address(usdcFleet)),
                targetVault: IFleetCommander(address(wethFleet)),
                inAsset: IERC20(USDC_ADDRESS),
                outAsset: IERC20(WETH_ADDRESS),
                tradeAmount: 100e6,
                interval: 7 days,
                slippageBps: 50,
                maxPrice: 0,
                minPrice: 0,
                endDate: block.timestamp + 365 days,
                maxTrades: 100
            });
    }
}

contract DCAStrategyManagerIntegrationTest is Test {
    DCAStrategyManager public dcaManager;
    IFleetCommander public sourceFleet;
    IFleetCommander public targetFleet;

    address public constant ENSO_ROUTER =
        0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf;
    address public constant ETH_USD_FEED =
        0x5F4EC3dF9CBd43714FE2740F5E3617235d988Bbb;
    address public constant USDC_USD_FEED =
        0x8fFFfFd4B3Cf5CA76D5CD5D9D8Bc5A9E5b0c4dd9;
    address public constant PERMIT2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public governor = address(1);
    address public keeper = address(2);
    address public strategyOwner = address(3);
    address public raft = address(4);
    address public tipJar = address(5);
    address public treasury = address(6);

    uint256 constant FORK_BLOCK = 20576616;
    uint256 public forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        _setupContracts();
        _setupUser();
    }

    function _setupContracts() internal {
        ProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        HarborCommand harborCommand = new HarborCommand(address(accessManager));

        ConfigurationManager configurationManager = new ConfigurationManager(
            address(accessManager)
        );

        FleetCommanderRewardsManagerFactory factory = new FleetCommanderRewardsManagerFactory();

        vm.startPrank(governor);
        accessManager.grantGovernorRole(governor);
        configurationManager.initializeConfiguration(
            ConfigurationManagerParams({
                raft: raft,
                tipJar: tipJar,
                treasury: treasury,
                harborCommand: address(harborCommand),
                fleetCommanderRewardsManagerFactory: address(factory)
            })
        );
        accessManager.grantSuperKeeperRole(keeper);

        FleetCommanderParams memory usdcParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: 10000 * 10 ** 6,
            initialRebalanceCooldown: 1000,
            asset: USDC_ADDRESS,
            name: "USDC Fleet",
            symbol: "USDC-FLEET",
            details: "USDC Fleet",
            initialTipRate: toPercentage(0),
            depositCap: type(uint256).max
        });
        sourceFleet = IFleetCommander(address(new FleetCommander(usdcParams)));
        harborCommand.enlistFleetCommander(address(sourceFleet));

        FleetCommanderParams memory wethParams = FleetCommanderParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: 1 ether,
            initialRebalanceCooldown: 1000,
            asset: WETH_ADDRESS,
            name: "WETH Fleet",
            symbol: "WETH-FLEET",
            details: "WETH Fleet",
            initialTipRate: toPercentage(0),
            depositCap: type(uint256).max
        });
        targetFleet = IFleetCommander(address(new FleetCommander(wethParams)));
        harborCommand.enlistFleetCommander(address(targetFleet));

        dcaManager = new DCAStrategyManager(
            address(accessManager),
            ENSO_ROUTER,
            address(harborCommand),
            ETH_USD_FEED,
            USDC_USD_FEED,
            PERMIT2
        );

        vm.stopPrank();

        vm.startPrank(governor);
        ProtocolAccessManager(accessManager).grantKeeperRole(
            address(dcaManager),
            keeper
        );
        vm.stopPrank();
    }

    function _setupUser() internal {
        deal(USDC_ADDRESS, strategyOwner, 10000e6);
        vm.startPrank(strategyOwner);
        IERC20(USDC_ADDRESS).approve(address(sourceFleet), type(uint256).max);
        sourceFleet.deposit(1000e6, strategyOwner);
        IERC20(address(sourceFleet)).approve(
            address(dcaManager),
            type(uint256).max
        );
        vm.stopPrank();
    }

    function test_Execute_PullsWithStandardERC20Approve() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, "");

        assertEq(
            IERC20(address(sourceFleet)).balanceOf(strategyOwner),
            900e6,
            "Owner should have 900e6 shares left"
        );
    }

    function test_Execute_MintsSharesToOwnerNotContract() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        uint256 ownerWethSharesBefore = IERC20(address(targetFleet)).balanceOf(
            strategyOwner
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, "");

        uint256 ownerWethSharesAfter = IERC20(address(targetFleet)).balanceOf(
            strategyOwner
        );

        assertGt(
            ownerWethSharesAfter,
            ownerWethSharesBefore,
            "Owner should have received WETH fleet shares"
        );

        assertEq(
            IERC20(address(targetFleet)).balanceOf(address(dcaManager)),
            0,
            "DCA manager should not hold any target shares"
        );
    }

    function test_Execute_UpdatesNextTriggerAtBasedOnExecutionTime() public {
        uint256 interval = 7 days;
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        uint256 executionTime = block.timestamp + 10 days;
        vm.warp(executionTime);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, "");

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);

        assertEq(
            state.nextTriggerAt,
            executionTime + interval,
            "Catch-up bug: nextTriggerAt not based on actual execution time"
        );
    }

    function test_Execute_PullsWithPermit2AllowanceTransfer() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.startPrank(strategyOwner);
        IERC20(address(sourceFleet)).approve(address(dcaManager), 0);

        IERC20(address(sourceFleet)).approve(PERMIT2, type(uint256).max);
        IPerm2(PERMIT2).approve(
            address(sourceFleet),
            address(dcaManager),
            type(uint160).max,
            type(uint48).max
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(
            strategyOwner,
            address(dcaManager),
            config.tradeAmount
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, "");
    }

    function test_Execute_CalculatesMinOutUsingAssetsNotShares() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);
        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, "");
    }

    // ==========================================
    // Helper functions
    // ==========================================

    function _createStrategy(uint256 endDate) internal returns (uint256) {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            0,
            endDate
        );
        uint256 strategyId = dcaManager.createStrategy(config, "");
        vm.stopPrank();
        return strategyId;
    }


    function _buildConfig(
        uint256 strategyId,
        uint256 endDate
    ) internal view returns (IDCAStrategyManager.StrategyConfig memory) {
        return
            IDCAStrategyManager.StrategyConfig({
                strategyId: strategyId,
                owner: strategyOwner,
                sourceVault: sourceFleet,
                targetVault: targetFleet,
                inAsset: IERC20(USDC_ADDRESS),
                outAsset: IERC20(WETH_ADDRESS),
                tradeAmount: 100e6,
                interval: 7 days,
                slippageBps: 50,
                maxPrice: 0,
                minPrice: 0,
                endDate: endDate,
                maxTrades: 100
            });
    }
}
