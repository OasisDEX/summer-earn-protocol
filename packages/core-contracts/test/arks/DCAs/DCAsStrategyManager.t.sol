// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "../../../src/contracts/FleetCommander.sol";
import {DCAStrategyManager} from "../../../src/contracts/DCA/DCAStrategyManager.sol";
import {IDCAStrategyManager} from "../../../src/interfaces/arks/IDCAStrategyManager.sol";
import {IFleetCommander} from "../../../src/interfaces/IFleetCommander.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {FleetCommanderParams} from "../../../src/types/FleetCommanderTypes.sol";
import {toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {HarborCommand} from "../../../src/contracts/HarborCommand.sol";
import {FleetCommanderRewardsManagerFactory} from "../../../src/contracts/FleetCommanderRewardsManagerFactory.sol";
import {Test, console} from "forge-std/Test.sol";
import {IPermit2} from "../../../src/interfaces/permit2/IPermit2.sol";
import {AggregatorV3Interface} from "../../../src/interfaces/external/Chainlink/AggregatorV3Interface.sol";

/// @notice Test-only mock that stands in for the Enso router. On any call it
/// pulls a configured amount of source token from the caller (using its
/// approval) and deposits a configured amount of the destination underlying
/// asset into the destination FleetCommander, minting shares directly to the
/// caller. This lets us exercise the swap pipeline without real Enso calldata.
contract MockEnsoRouter {
    using SafeERC20 for IERC20;

    IERC20 public srcToken;
    uint256 public srcAmount;
    IERC20 public dstAsset;
    uint256 public dstAssetAmount;
    IFleetCommander public dstVault;

    function setSwap(
        IERC20 _src,
        uint256 _srcAmt,
        IERC20 _dstAsset,
        uint256 _dstAssetAmt,
        IFleetCommander _dstVault
    ) external {
        srcToken = _src;
        srcAmount = _srcAmt;
        dstAsset = _dstAsset;
        dstAssetAmount = _dstAssetAmt;
        dstVault = _dstVault;
    }

    fallback() external {
        srcToken.safeTransferFrom(msg.sender, address(this), srcAmount);
        dstAsset.forceApprove(address(dstVault), dstAssetAmount);
        dstVault.deposit(dstAssetAmount, msg.sender);
    }

    receive() external payable {}
}

/// @notice Variant of MockEnsoRouter that pulls less than the configured
/// srcAmount, simulating a router that doesn't consume the full approval.
contract MockEnsoRouterUnderpull {
    using SafeERC20 for IERC20;

    IERC20 public srcToken;
    uint256 public srcPullAmount;
    IERC20 public dstAsset;
    uint256 public dstAssetAmount;
    IFleetCommander public dstVault;

    function setSwap(
        IERC20 _src,
        uint256 _srcPull,
        IERC20 _dstAsset,
        uint256 _dstAssetAmt,
        IFleetCommander _dstVault
    ) external {
        srcToken = _src;
        srcPullAmount = _srcPull;
        dstAsset = _dstAsset;
        dstAssetAmount = _dstAssetAmt;
        dstVault = _dstVault;
    }

    fallback() external {
        srcToken.safeTransferFrom(msg.sender, address(this), srcPullAmount);
        dstAsset.forceApprove(address(dstVault), dstAssetAmount);
        dstVault.deposit(dstAssetAmount, msg.sender);
    }

    receive() external payable {}
}

contract DCAStrategyManagerTest is Test {
    DCAStrategyManager public dcaManager;
    FleetCommander public usdcFleet;
    FleetCommander public wethFleet;

    address public constant ENSO_ROUTER =
        0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf;
    address public constant ETH_USD_FEED =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDC_USD_FEED =
        0x789190466E21a8b78b8027866CBBDc151542A26C;
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
        // Pin fork time to an hour boundary so the contract's hour-aligned
        // nextTriggerAt math lines up with `vm.warp(block.timestamp + N)` in
        // tests without per-test offsets.
        vm.warp(((block.timestamp + 3599) / 3600) * 3600);
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
        dcaManager.createStrategy(config);
        vm.stopPrank();
    }

    function test_CheckUpkeep_ReturnsTrueWhenReady() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        config.strategyId = dcaManager.createStrategy(config);
        vm.stopPrank();

        (bool upkeepNeededBefore, ) = dcaManager.checkUpkeep(config);
        assertFalse(
            upkeepNeededBefore,
            "Upkeep should be false before interval"
        );

        vm.warp(block.timestamp + 7 days);

        (bool upkeepNeededAfter, ) = dcaManager.checkUpkeep(config);
        assertTrue(upkeepNeededAfter, "Upkeep should be true after interval");
    }

    function test_CreateStrategy_AssignsUniqueIdAndCommitment() public {
        vm.startPrank(strategyOwner);

        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();

        uint256 strategyId = dcaManager.createStrategy(config);

        assertEq(strategyId, 0, "First strategy should have id 0");
        assertTrue(
            dcaManager.strategyCommitments(strategyId) != bytes32(0),
            "Commitment should be set"
        );

        IDCAStrategyManager.StrategyConfig memory config2 = _defaultConfig();
        config2.owner = address(0x2222);
        uint256 strategyId2 = dcaManager.createStrategy(config2);

        assertEq(strategyId2, 1, "Second strategy should have id 1");

        vm.stopPrank();
    }

    function test_PauseAndResume_UpdatesStateCorrectly() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        config.strategyId = dcaManager.createStrategy(config);

        dcaManager.pauseStrategy(config.strategyId);

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(config.strategyId);
        assertEq(state.status, uint8(IDCAStrategyManager.Status.PAUSED));

        dcaManager.resumeStrategy(config);

        state = dcaManager.strategyStates(config.strategyId);
        assertEq(state.status, uint8(IDCAStrategyManager.Status.ACTIVE));
        vm.stopPrank();
    }

    function test_CancelStrategy_PreventsFurtherExecutions() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig());

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
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig());
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
        uint256 strategyId = dcaManager.createStrategy(config);
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
        dcaManager.createStrategy(_defaultConfig());
        vm.stopPrank();

        IDCAStrategyManager.StrategyConfig memory execConfig = _defaultConfig();

        vm.expectRevert();
        dcaManager.executeDCA(execConfig, "");
    }

    function test_EditStrategy_UpdatesCommitmentAndSchedule() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig());

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
                inAssetFeed: USDC_USD_FEED,
                outAssetFeed: ETH_USD_FEED,
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
    MockEnsoRouter public ensoRouter;
    ProtocolAccessManager public accessManager;
    HarborCommand public harborCommand;

    address public constant ETH_USD_FEED =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDC_USD_FEED =
        0x789190466E21a8b78b8027866CBBDc151542A26C;
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

    /// @dev Amount of WETH the mock router will deposit into the target vault
    /// on each swap. Generous (0.05 WETH per 100 USDC) so it comfortably
    /// exceeds the contract's minOut at any realistic fork-time ETH price.
    uint256 public constant MOCK_WETH_OUT = 0.05 ether;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        // Pin fork time to an hour boundary so the contract's hour-aligned
        // nextTriggerAt math lines up with `vm.warp(block.timestamp + N)` in
        // tests without per-test offsets.
        vm.warp(((block.timestamp + 3599) / 3600) * 3600);
        _setupContracts();
        _setupUser();
    }

    function _setupContracts() internal {
        accessManager = new ProtocolAccessManager(governor);

        harborCommand = new HarborCommand(address(accessManager));

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

        // Share transfers are gated by FleetCommander; the DCA flow pulls
        // source shares from the owner via Permit2.transferFrom, which calls
        // the underlying ERC20 transferFrom. Enable transfers on both fleets.
        FleetCommander(address(sourceFleet)).setFleetTokenTransferability();
        FleetCommander(address(targetFleet)).setFleetTokenTransferability();

        vm.stopPrank();

        ensoRouter = new MockEnsoRouter();

        vm.startPrank(governor);
        dcaManager = new DCAStrategyManager(
            address(accessManager),
            address(ensoRouter),
            address(harborCommand),
            PERMIT2
        );

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

        // Default path: Permit2 AllowanceTransfer approval. Tests that need
        // a different setup override this explicitly.
        IERC20(address(sourceFleet)).approve(PERMIT2, type(uint256).max);
        IPermit2(PERMIT2).approve(
            address(sourceFleet),
            address(dcaManager),
            type(uint160).max,
            type(uint48).max
        );
        vm.stopPrank();

        // Pre-fund the mock router with WETH so it can deposit into the
        // target vault when called.
        deal(WETH_ADDRESS, address(ensoRouter), 100 ether);
        ensoRouter.setSwap(
            IERC20(address(sourceFleet)),
            100e6,
            IERC20(WETH_ADDRESS),
            MOCK_WETH_OUT,
            targetFleet
        );

        _mockOracles(1e8, 3000e8);
    }

    /// @dev Mock the Chainlink price feeds at the constant addresses. The
    /// real proxy at USDC_USD_FEED gates `latestRoundData` with an access
    /// list that excludes contract callers; mocking sidesteps both the
    /// access check and any fork-time-of-day flakiness in the oracle
    /// price. Default: 8 decimals like production mainnet feeds.
    function _mockOracles(int256 inPrice, int256 outPrice) internal {
        _mockOracles(inPrice, outPrice, 8, 8);
    }

    function _mockOracles(
        int256 inPrice,
        int256 outPrice,
        uint8 inDec,
        uint8 outDec
    ) internal {
        vm.mockCall(
            USDC_USD_FEED,
            abi.encodeWithSelector(
                AggregatorV3Interface.latestRoundData.selector
            ),
            abi.encode(
                uint80(1),
                inPrice,
                uint256(block.timestamp),
                uint256(block.timestamp),
                uint80(1)
            )
        );
        vm.mockCall(
            USDC_USD_FEED,
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(inDec)
        );
        vm.mockCall(
            ETH_USD_FEED,
            abi.encodeWithSelector(
                AggregatorV3Interface.latestRoundData.selector
            ),
            abi.encode(
                uint80(1),
                outPrice,
                uint256(block.timestamp),
                uint256(block.timestamp),
                uint80(1)
            )
        );
        vm.mockCall(
            ETH_USD_FEED,
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(outDec)
        );
    }

    function test_Execute_RevertsOnEmptyEnsoData() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("EmptyEnsoData(uint256)", strategyId)
        );
        dcaManager.executeDCA(config, "");
    }

    function test_Execute_RevertsWithoutPermit2Allowance() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        // Revoke Permit2 setup that _setupUser put in place.
        vm.startPrank(strategyOwner);
        IPermit2(PERMIT2).approve(
            address(sourceFleet),
            address(dcaManager),
            0,
            0
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.prank(keeper);
        vm.expectRevert();
        dcaManager.executeDCA(config, hex"deadbeef");
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
        dcaManager.executeDCA(config, hex"deadbeef");

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
        dcaManager.executeDCA(config, hex"deadbeef");

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

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.expectEmit(true, true, true, true, address(sourceFleet));
        emit IERC20.Transfer(
            strategyOwner,
            address(dcaManager),
            config.tradeAmount
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, hex"deadbeef");
    }

    function test_Execute_CalculatesMinOutUsingAssetsNotShares() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        uint256 sourceSharesBefore = IERC20(address(sourceFleet)).balanceOf(
            strategyOwner
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, hex"deadbeef");

        // 100e6 source shares pulled from owner.
        assertEq(
            IERC20(address(sourceFleet)).balanceOf(strategyOwner),
            sourceSharesBefore - 100e6,
            "100e6 source shares should have been pulled"
        );

        // Target shares minted to owner reflect the new previewDeposit-based
        // calculation. With a fresh WETH fleet (1:1) and 0.05 WETH dealt in,
        // owner should hold ~0.05e18 WETH-fleet shares.
        uint256 ownerWethShares = IERC20(address(targetFleet)).balanceOf(
            strategyOwner
        );
        assertGt(
            ownerWethShares,
            0,
            "Owner should hold target shares after execution"
        );
        assertLe(
            ownerWethShares,
            MOCK_WETH_OUT,
            "Target shares cannot exceed deposited WETH (1:1 in fresh vault)"
        );
    }

    function test_Execute_HandlesFeedsWithDifferentDecimals() public {
        // Override the default 8-decimal mocks with mismatched feed
        // precisions: USDC feed at 6 decimals (price 1e6), ETH feed at
        // 18 decimals (price 3000e18). The math must remain correct.
        _mockOracles(int256(1e6), int256(3000e18), 6, 18);

        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        // Re-mock after the warp so block.timestamp matches.
        _mockOracles(int256(1e6), int256(3000e18), 6, 18);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, hex"deadbeef");

        uint256 ownerWethShares = IERC20(address(targetFleet)).balanceOf(
            strategyOwner
        );
        assertGt(
            ownerWethShares,
            0,
            "Math should still yield positive target shares with heterogeneous feed decimals"
        );
        assertLe(
            ownerWethShares,
            MOCK_WETH_OUT,
            "Target shares cannot exceed deposited WETH"
        );
    }

    function test_Execute_ClearsEnsoAllowance() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            strategyId,
            endDate
        );

        vm.prank(keeper);
        dcaManager.executeDCA(config, hex"deadbeef");

        assertEq(
            IERC20(address(sourceFleet)).allowance(
                address(dcaManager),
                address(ensoRouter)
            ),
            0,
            "Router allowance must be reset to zero post-swap"
        );
    }

    function test_Execute_LeavesZeroAllowanceWhenRouterUnderspends() public {
        // Swap out the default MockEnsoRouter for one that only pulls half
        // the approved amount. The contract approved 100e6 but the router
        // takes 50e6 — without the explicit reset, 50e6 would linger.
        MockEnsoRouterUnderpull underpull = new MockEnsoRouterUnderpull();
        deal(WETH_ADDRESS, address(underpull), 100 ether);
        underpull.setSwap(
            IERC20(address(sourceFleet)),
            50e6,
            IERC20(WETH_ADDRESS),
            MOCK_WETH_OUT,
            targetFleet
        );

        vm.startPrank(governor);
        DCAStrategyManager newManager = new DCAStrategyManager(
            address(accessManager),
            address(underpull),
            address(harborCommand),
            PERMIT2
        );
        accessManager.grantKeeperRole(address(newManager), keeper);
        vm.stopPrank();

        // Re-route Permit2 allowance from the original manager to this one.
        vm.startPrank(strategyOwner);
        IPermit2(PERMIT2).approve(
            address(sourceFleet),
            address(newManager),
            type(uint160).max,
            type(uint48).max
        );
        vm.stopPrank();

        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory createConfig = _buildConfig(
            0,
            endDate
        );
        vm.prank(strategyOwner);
        uint256 strategyId = newManager.createStrategy(createConfig);

        vm.warp(block.timestamp + 7 days);
        _mockOracles(int256(1e8), int256(3000e8));

        IDCAStrategyManager.StrategyConfig memory execConfig = _buildConfig(
            strategyId,
            endDate
        );

        vm.prank(keeper);
        newManager.executeDCA(execConfig, hex"deadbeef");

        assertEq(
            IERC20(address(sourceFleet)).allowance(
                address(newManager),
                address(underpull)
            ),
            0,
            "Allowance must be zero even when router under-spends the approval"
        );
    }

    function _createStrategy(uint256 endDate) internal returns (uint256) {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            0,
            endDate
        );
        uint256 strategyId = dcaManager.createStrategy(config);
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
                inAssetFeed: USDC_USD_FEED,
                outAssetFeed: ETH_USD_FEED,
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
