// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "../../../src/contracts/FleetCommander.sol";
import {DCAStrategyManager} from "../../../src/contracts/DCA/DCAStrategyManager.sol";
import {IDCAStrategyManager} from "../../../src/interfaces/arks/IDCAStrategyManager.sol";
import {IDCAStrategyManagerErrors} from "../../../src/errors/arks/IDCAStrategyManagerErrors.sol";
import {IDCAStrategyManagerEvents} from "../../../src/events/arks/IDCAStrategyManagerEvents.sol";
import {EnsoRouterSwapper} from "../../../src/utils/EnsoRouterSwapper.sol";
import {HarborCommandConsumer} from "../../../src/utils/HarborCommandConsumer.sol";
import {ChainlinkOracleUtils} from "../../../src/utils/ChainlinkOracleUtils.sol";
import {Permit2Consumer} from "../../../src/utils/Permit2Consumer.sol";
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
import {Vm} from "forge-std/Vm.sol";
import {IPermit2, IAllowanceTransfer, ISignatureTransfer} from "../../../src/interfaces/permit2/IPermit2.sol";
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

/// @notice Minimal Chainlink AggregatorV3Interface mock. Returns `block.timestamp`
/// as `updatedAt` on every call so tests that warp forward never hit the
/// staleness check without explicitly overriding the feed via vm.mockCall.
contract MockChainlinkFeed {
    int256 public price;
    uint8 public dec;

    constructor(int256 _price, uint8 _dec) {
        price = _price;
        dec = _dec;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }
    function setDecimals(uint8 _dec) external {
        dec = _dec;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, price, block.timestamp, block.timestamp, 1);
    }

    function decimals() external view returns (uint8) {
        return dec;
    }
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
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.IntervalTooShort.selector,
                uint256(1 hours),
                uint256(1 days)
            )
        );
        dcaManager.createStrategy(config);
        vm.stopPrank();
    }

    function test_CreateStrategy_AcceptsOneDayInterval() public {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.interval = 1 days;

        // Just asserting it doesn't revert — the minimum boundary is 1 day.
        uint256 strategyId = dcaManager.createStrategy(config);
        assertGt(
            uint256(dcaManager.strategyStates(strategyId).nextTriggerAt),
            0,
            "1-day interval must be accepted by _validateStrategyConfig"
        );
        vm.stopPrank();
    }

    function test_CreateStrategy_RevertsIfIntervalTooLong() public {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.interval = 91 days;

        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.IntervalTooLong.selector,
                uint256(91 days),
                uint256(90 days)
            )
        );
        dcaManager.createStrategy(config);
        vm.stopPrank();
    }

    function test_CreateStrategy_AcceptsNinetyDayInterval() public {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.interval = 90 days;

        // 90 days is the inclusive upper bound — must not revert.
        uint256 strategyId = dcaManager.createStrategy(config);
        assertGt(
            uint256(dcaManager.strategyStates(strategyId).nextTriggerAt),
            0,
            "90-day interval must be accepted by _validateStrategyConfig"
        );
        vm.stopPrank();
    }

    function test_CreateStrategy_RevertsOnInvalidSlippage() public {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.slippageBps = 10_001;

        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.InvalidSlippage.selector,
                uint256(10_001)
            )
        );
        dcaManager.createStrategy(config);
        vm.stopPrank();
    }

    function test_CreateStrategy_RevertsOnZeroTradeAmount() public {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.tradeAmount = 0;

        vm.expectRevert(IDCAStrategyManagerErrors.ZeroTradeAmount.selector);
        dcaManager.createStrategy(config);
        vm.stopPrank();
    }

    function test_CreateStrategy_RevertsOnInvalidFeedAddress() public {
        vm.startPrank(strategyOwner);

        IDCAStrategyManager.StrategyConfig memory zeroIn = _defaultConfig();
        zeroIn.inAssetFeed = address(0);
        vm.expectRevert(IDCAStrategyManagerErrors.InvalidFeedAddress.selector);
        dcaManager.createStrategy(zeroIn);

        IDCAStrategyManager.StrategyConfig memory zeroOut = _defaultConfig();
        zeroOut.outAssetFeed = address(0);
        vm.expectRevert(IDCAStrategyManagerErrors.InvalidFeedAddress.selector);
        dcaManager.createStrategy(zeroOut);

        vm.stopPrank();
    }

    function test_CreateStrategy_RevertsOnInvalidSourceVault() public {
        IFleetCommander rogue = IFleetCommander(address(0xDEAD));
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.sourceVault = rogue;

        vm.expectRevert(
            abi.encodeWithSelector(
                HarborCommandConsumer.InactiveFleetCommander.selector,
                address(rogue),
                "source"
            )
        );
        dcaManager.createStrategy(config);
        vm.stopPrank();
    }

    function test_CreateStrategy_RevertsOnInvalidTargetVault() public {
        IFleetCommander rogue = IFleetCommander(address(0xDEAD));
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.targetVault = rogue;

        vm.expectRevert(
            abi.encodeWithSelector(
                HarborCommandConsumer.InactiveFleetCommander.selector,
                address(rogue),
                "target"
            )
        );
        dcaManager.createStrategy(config);
        vm.stopPrank();
    }

    function test_CreateStrategy_RevertsOnZeroMaxTrades() public {
        // maxTrades = 0 is NOT a sentinel for "unlimited" — it must be rejected.
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.maxTrades = 0;

        vm.prank(strategyOwner);
        vm.expectRevert(IDCAStrategyManagerErrors.ZeroMaxTrades.selector);
        dcaManager.createStrategy(config);
    }

    function test_CheckUpkeep_ReturnsFalseOnEndDatePassed() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.endDate = block.timestamp + 8 days;
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        // Warp past endDate. The interval gate would otherwise be satisfied
        // (block.timestamp >= nextTriggerAt) — endDate guard must still flip
        // checkUpkeep to false.
        vm.warp(block.timestamp + 9 days);

        (bool upkeepNeeded, ) = dcaManager.checkUpkeep(strategyId, config);
        assertFalse(upkeepNeeded, "Upkeep should be false past endDate");
    }

    function test_CheckUpkeep_ReturnsTrueWhenReady() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        vm.stopPrank();

        (bool upkeepNeededBefore, ) = dcaManager.checkUpkeep(
            strategyId,
            config
        );
        assertFalse(
            upkeepNeededBefore,
            "Upkeep should be false before interval"
        );

        vm.warp(block.timestamp + 7 days);

        (bool upkeepNeededAfter, ) = dcaManager.checkUpkeep(strategyId, config);
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

        vm.startPrank(config2.owner);
        uint256 strategyId2 = dcaManager.createStrategy(config2);

        assertEq(strategyId2, 1, "Second strategy should have id 1");

        vm.stopPrank();
    }

    function test_PauseAndResume_UpdatesStateCorrectly() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        dcaManager.pauseStrategy(strategyId, config);

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(uint8(state.status), uint8(IDCAStrategyManager.Status.PAUSED));

        dcaManager.resumeStrategy(strategyId, config);

        state = dcaManager.strategyStates(strategyId);
        assertEq(uint8(state.status), uint8(IDCAStrategyManager.Status.ACTIVE));
        vm.stopPrank();
    }

    function test_CancelStrategy_PreventsFurtherExecutions() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        dcaManager.cancelStrategy(strategyId, config);

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(
            uint8(state.status),
            uint8(IDCAStrategyManager.Status.CANCELLED)
        );
        vm.stopPrank();

        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.StrategyNotActive.selector,
                strategyId
            )
        );
        dcaManager.pauseStrategy(strategyId, config);
    }

    function test_PauseStrategy_RevertsForNonOwner() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        address attacker = address(0xBAD);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.UnauthorizedAccess.selector,
                strategyId,
                attacker
            )
        );
        dcaManager.pauseStrategy(strategyId, config);
    }

    function test_PauseStrategy_RevertsOnCommitmentMismatch() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        IDCAStrategyManager.StrategyConfig memory wrong = _defaultConfig();
        wrong.tradeAmount = 1234;

        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.CommitmentMismatch.selector,
                strategyId
            )
        );
        dcaManager.pauseStrategy(strategyId, wrong);
    }

    function test_Execute_RevertsOnCommitmentMismatch() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig());
        vm.stopPrank();

        IDCAStrategyManager.StrategyConfig
            memory wrongConfig = _defaultConfig();
        wrongConfig.tradeAmount = 1000e18;

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.CommitmentMismatch.selector,
                strategyId
            )
        );
        dcaManager.executeStrategy(strategyId, wrongConfig, "");
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
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.CommitmentMismatch.selector,
                strategyId
            )
        );
        dcaManager.executeStrategy(strategyId, wrongConfig, "");
    }

    function test_Execute_RevertsIfNotKeeper() public {
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig());
        vm.stopPrank();

        IDCAStrategyManager.StrategyConfig memory execConfig = _defaultConfig();

        vm.expectRevert();
        dcaManager.executeStrategy(strategyId, execConfig, "");
    }

    function test_EditStrategy_UpdatesCommitmentAndSchedule() public {
        IDCAStrategyManager.StrategyConfig memory oldConfig = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(oldConfig);

        IDCAStrategyManager.StrategyConfig memory newConfig = _defaultConfig();
        newConfig.interval = 8 days;

        dcaManager.editStrategy(strategyId, oldConfig, newConfig);

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(state.nextTriggerAt, state.lastScheduledAt + 8 days);

        vm.stopPrank();
    }

    function test_EditStrategy_RevertsOnOwnershipTransfer() public {
        IDCAStrategyManager.StrategyConfig memory oldConfig = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(oldConfig);

        IDCAStrategyManager.StrategyConfig memory newConfig = _defaultConfig();
        newConfig.owner = address(0xCAFE);

        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.UnauthorizedAccess.selector,
                strategyId,
                strategyOwner
            )
        );
        dcaManager.editStrategy(strategyId, oldConfig, newConfig);
        vm.stopPrank();
    }

    function test_EditStrategy_RevertsForNonOwner() public {
        IDCAStrategyManager.StrategyConfig memory oldConfig = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(oldConfig);

        IDCAStrategyManager.StrategyConfig memory newConfig = _defaultConfig();
        newConfig.interval = 14 days;

        address attacker = address(0xBAD);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.UnauthorizedAccess.selector,
                strategyId,
                attacker
            )
        );
        dcaManager.editStrategy(strategyId, oldConfig, newConfig);
    }

    function test_CreateStrategy_RevertsOnDuplicate() public {
        vm.startPrank(strategyOwner);

        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        dcaManager.createStrategy(config);

        vm.expectRevert(IDCAStrategyManagerErrors.DuplicateStrategy.selector);
        dcaManager.createStrategy(config);

        // Mutating any field (here: endDate) yields a different fingerprint
        // and the second create succeeds.
        IDCAStrategyManager.StrategyConfig memory other = _defaultConfig();
        other.endDate = block.timestamp + 730 days;
        dcaManager.createStrategy(other);

        vm.stopPrank();
    }

    function test_EditStrategy_RevertsOnDuplicate() public {
        vm.startPrank(strategyOwner);

        // Strategy A: default config.
        dcaManager.createStrategy(_defaultConfig());

        // Strategy B: distinct config (different interval).
        IDCAStrategyManager.StrategyConfig memory bConfig = _defaultConfig();
        bConfig.interval = 14 days;
        uint256 bId = dcaManager.createStrategy(bConfig);

        // Editing B back to A's exact config must collide.
        vm.expectRevert(IDCAStrategyManagerErrors.DuplicateStrategy.selector);
        dcaManager.editStrategy(bId, bConfig, _defaultConfig());

        vm.stopPrank();
    }

    function test_EditStrategy_FreesOldCommitmentForReuse() public {
        vm.startPrank(strategyOwner);

        IDCAStrategyManager.StrategyConfig memory original = _defaultConfig();
        uint256 strategyId = dcaManager.createStrategy(original);
        bytes32 oldHash = keccak256(abi.encode(original));

        IDCAStrategyManager.StrategyConfig memory edited = _defaultConfig();
        edited.interval = 21 days;
        dcaManager.editStrategy(strategyId, original, edited);
        bytes32 newHash = keccak256(abi.encode(edited));

        assertFalse(
            dcaManager.activeCommitments(oldHash),
            "Old commitment should be freed after edit"
        );
        assertTrue(
            dcaManager.activeCommitments(newHash),
            "New commitment should be registered"
        );

        // The original commitment is now reusable.
        dcaManager.createStrategy(original);

        vm.stopPrank();
    }

    function test_CancelledCommitmentStaysLocked() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.cancelStrategy(strategyId, config);

        // Terminal states do NOT free the commitment — the user must mutate
        // a field (e.g. endDate) to create a "new" identical strategy.
        vm.expectRevert(IDCAStrategyManagerErrors.DuplicateStrategy.selector);
        dcaManager.createStrategy(_defaultConfig());

        vm.stopPrank();
    }

    function _defaultConfig()
        internal
        view
        returns (IDCAStrategyManager.StrategyConfig memory)
    {
        return
            IDCAStrategyManager.StrategyConfig({
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

    // =========================================================
    // createStrategy — additional validation paths
    // =========================================================

    function test_CreateStrategy_RevertsOnInvalidOwner() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.owner = address(0);
        vm.prank(config.owner);
        vm.expectRevert(IDCAStrategyManagerErrors.InvalidOwner.selector);
        dcaManager.createStrategy(config);
    }

    function test_CreateStrategy_RevertsOnSameVault() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.targetVault = config.sourceVault;
        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.SameAsset.selector,
                address(config.sourceVault)
            )
        );
        dcaManager.createStrategy(config);
    }

    function test_CreateStrategy_RevertsOnSameAsset() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.outAsset = config.inAsset;
        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.SameAsset.selector,
                address(config.inAsset)
            )
        );
        dcaManager.createStrategy(config);
    }

    function test_CreateStrategy_RevertsOnInAssetVaultMismatch() public {
        // sourceVault = usdcFleet (asset = USDC). Set inAsset to DAI so the
        // mismatch fires after the SameAsset check (outAsset is WETH).
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.inAsset = IERC20(dai);
        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.InAssetVaultMismatch.selector,
                USDC_ADDRESS,
                dai
            )
        );
        dcaManager.createStrategy(config);
    }

    function test_CreateStrategy_RevertsOnOutAssetVaultMismatch() public {
        // targetVault = wethFleet (asset = WETH). Set outAsset to DAI so the
        // mismatch fires after the SameAsset check (inAsset is USDC).
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.outAsset = IERC20(dai);
        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.OutAssetVaultMismatch.selector,
                WETH_ADDRESS,
                dai
            )
        );
        dcaManager.createStrategy(config);
    }

    function test_CreateStrategy_EmitsStrategyCreated() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        // Check strategyId (topic1) only; config struct data omitted.
        vm.expectEmit(true, false, false, false, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyCreated(0, config);
        dcaManager.createStrategy(config);
    }

    function test_DepositAndCreate_DepositsAndCreates() public {
        uint256 depositAmount = 1_000e6;
        deal(USDC_ADDRESS, strategyOwner, depositAmount);

        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();

        vm.startPrank(strategyOwner);
        IERC20(USDC_ADDRESS).approve(address(dcaManager), depositAmount);

        uint256 sharesBefore = usdcFleet.balanceOf(strategyOwner);
        uint256 strategyId = dcaManager.depositAndCreate(config, depositAmount);
        uint256 sharesAfter = usdcFleet.balanceOf(strategyOwner);
        vm.stopPrank();

        // Strategy was created.
        assertEq(strategyId, 0, "first strategy gets id 0");
        assertEq(
            uint8(dcaManager.strategyStates(strategyId).status),
            uint8(IDCAStrategyManager.Status.ACTIVE)
        );

        // Shares went directly to the user, not the manager.
        assertGt(
            sharesAfter,
            sharesBefore,
            "user must receive source-vault shares"
        );
        assertEq(
            usdcFleet.balanceOf(address(dcaManager)),
            0,
            "manager must not hold any source-vault shares after depositAndCreate"
        );

        // No leftover ERC20 allowance to the source vault.
        assertEq(
            IERC20(USDC_ADDRESS).allowance(
                address(dcaManager),
                address(usdcFleet)
            ),
            0,
            "manager's USDC allowance to source vault must be reset to 0"
        );

        // No leftover USDC sitting in the manager.
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(dcaManager)),
            0,
            "manager must not hold any USDC after depositAndCreate"
        );
    }

    function test_DepositAndCreate_RevertsOnZeroDeposit() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        vm.expectRevert(IDCAStrategyManagerErrors.ZeroDeposit.selector);
        dcaManager.depositAndCreate(config, 0);
    }

    function test_DepositAndCreate_RevertsForNonOwnerSender() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        address impostor = address(0xBEEF);
        deal(USDC_ADDRESS, impostor, 100e6);

        vm.startPrank(impostor);
        IERC20(USDC_ADDRESS).approve(address(dcaManager), 100e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.UnauthorizedOwner.selector,
                strategyOwner,
                impostor
            )
        );
        dcaManager.depositAndCreate(config, 100e6);
        vm.stopPrank();
    }

    function test_DepositAndCreate_RevertsOnInactiveSourceVault() public {
        // Decommission the source vault, then attempt deposit-and-create.
        vm.prank(governor);
        harborCommand.decommissionFleetCommander(address(usdcFleet));

        deal(USDC_ADDRESS, strategyOwner, 100e6);
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();

        vm.startPrank(strategyOwner);
        IERC20(USDC_ADDRESS).approve(address(dcaManager), 100e6);
        vm.expectRevert(
            abi.encodeWithSelector(
                HarborCommandConsumer.InactiveFleetCommander.selector,
                address(usdcFleet),
                "source"
            )
        );
        dcaManager.depositAndCreate(config, 100e6);
        vm.stopPrank();
    }

    function test_CreateStrategy_InitialStateIsCorrect() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        uint256 expectedHourAligned = ((block.timestamp + 3599) / 3600) * 3600;
        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);

        assertEq(uint8(state.status), uint8(IDCAStrategyManager.Status.ACTIVE));
        assertEq(state.tradesExecuted, 0);
        assertEq(state.lastScheduledAt, expectedHourAligned);
        assertEq(state.nextTriggerAt, expectedHourAligned + config.interval);
    }

    function test_CreateStrategy_AcceptsZeroSlippage() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.slippageBps = 0;
        vm.prank(strategyOwner);
        dcaManager.createStrategy(config);
    }

    function test_CreateStrategy_AcceptsMaxSlippage() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        config.slippageBps = 5_000;
        vm.prank(strategyOwner);
        dcaManager.createStrategy(config);
    }

    // =========================================================
    // editStrategy — additional paths
    // =========================================================

    function test_EditStrategy_RevertsOnCommitmentMismatch() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        IDCAStrategyManager.StrategyConfig memory wrong = _defaultConfig();
        wrong.tradeAmount = 9999;
        IDCAStrategyManager.StrategyConfig memory newConfig = _defaultConfig();
        newConfig.interval = 14 days;

        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.CommitmentMismatch.selector,
                strategyId
            )
        );
        dcaManager.editStrategy(strategyId, wrong, newConfig);
    }

    function test_EditStrategy_RevertsOnSameConfig() public {
        // Editing to the exact same config must revert with DuplicateStrategy:
        // the commitment is already active, so the new hash collides.
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        vm.prank(strategyOwner);
        vm.expectRevert(IDCAStrategyManagerErrors.DuplicateStrategy.selector);
        dcaManager.editStrategy(strategyId, config, config);
    }

    function test_EditStrategy_EmitsStrategyEdited() public {
        IDCAStrategyManager.StrategyConfig memory oldConfig = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(oldConfig);

        IDCAStrategyManager.StrategyConfig memory newConfig = _defaultConfig();
        newConfig.interval = 14 days;

        vm.prank(strategyOwner);
        vm.expectEmit(true, false, false, false, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyEdited(strategyId, newConfig);
        dcaManager.editStrategy(strategyId, oldConfig, newConfig);
    }

    function test_EditStrategy_WorksWhenPaused() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.pauseStrategy(strategyId, config);

        IDCAStrategyManager.StrategyConfig memory newConfig = _defaultConfig();
        newConfig.interval = 14 days;
        dcaManager.editStrategy(strategyId, config, newConfig);
        vm.stopPrank();

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(state.nextTriggerAt, state.lastScheduledAt + 14 days);
    }

    // =========================================================
    // pauseStrategy — additional paths
    // =========================================================

    function test_PauseStrategy_RevertsWhenAlreadyPaused() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.pauseStrategy(strategyId, config);

        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.StrategyNotActive.selector,
                strategyId
            )
        );
        dcaManager.pauseStrategy(strategyId, config);
        vm.stopPrank();
    }

    function test_PauseStrategy_EmitsStrategyPaused() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        uint256 expectedNextTriggerAt = dcaManager
            .strategyStates(strategyId)
            .nextTriggerAt;

        vm.prank(strategyOwner);
        vm.expectEmit(true, false, false, true, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyPaused(
            strategyId,
            expectedNextTriggerAt
        );
        dcaManager.pauseStrategy(strategyId, config);
    }

    // =========================================================
    // resumeStrategy — all paths
    // =========================================================

    function test_ResumeStrategy_RevertsForNonOwner() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        vm.prank(strategyOwner);
        dcaManager.pauseStrategy(strategyId, config);

        address attacker = address(0xBAD);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.UnauthorizedAccess.selector,
                strategyId,
                attacker
            )
        );
        dcaManager.resumeStrategy(strategyId, config);
    }

    function test_ResumeStrategy_RevertsOnCommitmentMismatch() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        vm.prank(strategyOwner);
        dcaManager.pauseStrategy(strategyId, config);

        IDCAStrategyManager.StrategyConfig memory wrong = _defaultConfig();
        wrong.tradeAmount = 9999;

        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.CommitmentMismatch.selector,
                strategyId
            )
        );
        dcaManager.resumeStrategy(strategyId, wrong);
    }

    function test_ResumeStrategy_RevertsWhenActive() public {
        // resumeStrategy requires PAUSED; calling it on an ACTIVE strategy must fail.
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.StrategyNotActive.selector,
                strategyId
            )
        );
        dcaManager.resumeStrategy(strategyId, config);
    }

    function test_ResumeStrategy_RevertsWhenCancelled() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.cancelStrategy(strategyId, config);

        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.StrategyNotActive.selector,
                strategyId
            )
        );
        dcaManager.resumeStrategy(strategyId, config);
        vm.stopPrank();
    }

    function test_ResumeStrategy_SetsNextTriggerAt() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.pauseStrategy(strategyId, config);

        vm.warp(block.timestamp + 30 days);
        dcaManager.resumeStrategy(strategyId, config);
        vm.stopPrank();

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(uint8(state.status), uint8(IDCAStrategyManager.Status.ACTIVE));
        assertEq(state.nextTriggerAt, block.timestamp + config.interval);
    }

    function test_ResumeStrategy_EmitsStrategyResumed() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.pauseStrategy(strategyId, config);

        vm.expectEmit(true, false, false, true, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyResumed(
            strategyId,
            block.timestamp + config.interval
        );
        dcaManager.resumeStrategy(strategyId, config);
        vm.stopPrank();
    }

    // =========================================================
    // cancelStrategy — additional paths
    // =========================================================

    function test_CancelStrategy_RevertsForNonOwner() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        address attacker = address(0xBAD);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.UnauthorizedAccess.selector,
                strategyId,
                attacker
            )
        );
        dcaManager.cancelStrategy(strategyId, config);
    }

    function test_CancelStrategy_RevertsOnCommitmentMismatch() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        IDCAStrategyManager.StrategyConfig memory wrong = _defaultConfig();
        wrong.tradeAmount = 9999;

        vm.prank(strategyOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.CommitmentMismatch.selector,
                strategyId
            )
        );
        dcaManager.cancelStrategy(strategyId, wrong);
    }

    function test_CancelStrategy_RevertsOnDoubleCancel() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.cancelStrategy(strategyId, config);

        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.StrategyNotActive.selector,
                strategyId
            )
        );
        dcaManager.cancelStrategy(strategyId, config);
        vm.stopPrank();
    }

    function test_CancelStrategy_WorksWhenPaused() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.pauseStrategy(strategyId, config);
        dcaManager.cancelStrategy(strategyId, config);
        vm.stopPrank();

        assertEq(
            uint8(dcaManager.strategyStates(strategyId).status),
            uint8(IDCAStrategyManager.Status.CANCELLED)
        );
    }

    function test_CancelStrategy_EmitsStrategyCancelled() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);

        vm.prank(strategyOwner);
        vm.expectEmit(true, false, false, false, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyCancelled(strategyId);
        dcaManager.cancelStrategy(strategyId, config);
    }

    // =========================================================
    // checkUpkeep — additional paths
    // =========================================================

    function test_CheckUpkeep_ReturnsFalseWhenPaused() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.pauseStrategy(strategyId, config);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        (bool upkeepNeeded, ) = dcaManager.checkUpkeep(strategyId, config);
        assertFalse(upkeepNeeded, "Upkeep must be false when PAUSED");
    }

    function test_CheckUpkeep_ReturnsFalseWhenCancelled() public {
        IDCAStrategyManager.StrategyConfig memory config = _defaultConfig();
        vm.startPrank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(config);
        dcaManager.cancelStrategy(strategyId, config);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        (bool upkeepNeeded, ) = dcaManager.checkUpkeep(strategyId, config);
        assertFalse(upkeepNeeded, "Upkeep must be false when CANCELLED");
    }

    function test_CheckUpkeep_ReturnsFalseOnWrongCommitment() public {
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(_defaultConfig());

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory wrong = _defaultConfig();
        wrong.tradeAmount = 9999;

        (bool upkeepNeeded, ) = dcaManager.checkUpkeep(strategyId, wrong);
        assertFalse(
            upkeepNeeded,
            "Upkeep must be false when commitment does not match"
        );
    }

    // =========================================================
    // Constructor guard checks
    // =========================================================

    function test_Constructor_RevertsOnZeroRouter() public {
        vm.expectRevert(EnsoRouterSwapper.InvalidRouterAddress.selector);
        new DCAStrategyManager(
            address(accessManager),
            address(0),
            address(harborCommand),
            PERMIT2
        );
    }

    function test_Constructor_RevertsOnZeroPermit2() public {
        vm.expectRevert(Permit2Consumer.InvalidPermit2Address.selector);
        new DCAStrategyManager(
            address(accessManager),
            ENSO_ROUTER,
            address(harborCommand),
            address(0)
        );
    }

    function test_Constructor_RevertsOnZeroHarborCommand() public {
        vm.expectRevert(
            HarborCommandConsumer.InvalidHarborCommandAddress.selector
        );
        new DCAStrategyManager(
            address(accessManager),
            ENSO_ROUTER,
            address(0),
            PERMIT2
        );
    }
}

contract DCAStrategyManagerIntegrationTest is Test {
    DCAStrategyManager public dcaManager;
    IFleetCommander public sourceFleet;
    IFleetCommander public targetFleet;
    MockEnsoRouter public ensoRouter;
    ProtocolAccessManager public accessManager;
    HarborCommand public harborCommand;
    MockChainlinkFeed public inFeedMock; // USDC/USD
    MockChainlinkFeed public outFeedMock; // ETH/USD

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
        inFeedMock = new MockChainlinkFeed(int256(1e8), 8); // USDC/USD  1.00 @ 8 dec
        outFeedMock = new MockChainlinkFeed(int256(3000e8), 8); // ETH/USD 3000.00 @ 8 dec

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
    }

    /// @dev Sets the price (and optionally decimals) on the MockChainlinkFeed
    /// contracts. The feeds return `block.timestamp` as `updatedAt` on every
    /// call, so tests never go stale after a vm.warp unless they explicitly
    /// override via vm.mockCall.
    function _mockOracles(int256 inPrice, int256 outPrice) internal {
        inFeedMock.setPrice(inPrice);
        outFeedMock.setPrice(outPrice);
    }

    function _mockOracles(
        int256 inPrice,
        int256 outPrice,
        uint8 inDec,
        uint8 outDec
    ) internal {
        inFeedMock.setPrice(inPrice);
        inFeedMock.setDecimals(inDec);
        outFeedMock.setPrice(outPrice);
        outFeedMock.setDecimals(outDec);
    }

    function test_Execute_RevertsOnEmptyEnsoData() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            endDate
        );

        vm.prank(keeper);
        vm.expectRevert(EnsoRouterSwapper.EmptySwapData.selector);
        dcaManager.executeStrategy(strategyId, config, "");
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
            endDate
        );

        vm.prank(keeper);
        vm.expectRevert();
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");
    }

    function test_Execute_MintsSharesToOwnerNotContract() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            endDate
        );

        uint256 ownerWethSharesBefore = IERC20(address(targetFleet)).balanceOf(
            strategyOwner
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");

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
            endDate
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");

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
            endDate
        );

        vm.expectEmit(true, true, true, true, address(sourceFleet));
        emit IERC20.Transfer(
            strategyOwner,
            address(dcaManager),
            config.tradeAmount
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");
    }

    function test_Execute_CalculatesMinOutUsingAssetsNotShares() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            endDate
        );

        uint256 sourceSharesBefore = IERC20(address(sourceFleet)).balanceOf(
            strategyOwner
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");

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
            endDate
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");

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
            endDate
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");

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
            endDate
        );
        vm.prank(strategyOwner);
        uint256 strategyId = newManager.createStrategy(createConfig);

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory execConfig = _buildConfig(
            endDate
        );

        vm.prank(keeper);
        newManager.executeStrategy(strategyId, execConfig, hex"deadbeef");

        assertEq(
            IERC20(address(sourceFleet)).allowance(
                address(newManager),
                address(underpull)
            ),
            0,
            "Allowance must be zero even when router under-spends the approval"
        );
    }

    function test_Execute_AutoCompletesOnMaxTrades() public {
        // Build a one-shot strategy via _buildConfig and override maxTrades=1.
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        cfg.maxTrades = 1;
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        vm.warp(block.timestamp + 7 days);

        vm.expectEmit(true, false, false, true, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyCompleted(
            strategyId,
            "max_trades"
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(
            uint8(state.status),
            uint8(IDCAStrategyManager.Status.COMPLETED),
            "Strategy should auto-transition to COMPLETED on maxTrades"
        );

        // A follow-up keeper call should now hit StrategyNotActive (status is COMPLETED).
        vm.warp(block.timestamp + 7 days);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.StrategyNotActive.selector,
                strategyId
            )
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_AutoCompletesOnEndDate() public {
        // Pick endDate so that after the FIRST execution, nextTriggerAt
        // (= block.timestamp + interval) lands at/after endDate.
        // execution happens at block.timestamp + 7 days; interval=7 days;
        // ⇒ nextTriggerAt = block.timestamp + 14 days. Set endDate to 14 days.
        uint256 endDate = block.timestamp + 14 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        vm.warp(block.timestamp + 7 days);

        vm.expectEmit(true, false, false, true, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyCompleted(
            strategyId,
            "end_date"
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");

        IDCAStrategyManager.StrategyState memory state = dcaManager
            .strategyStates(strategyId);
        assertEq(
            uint8(state.status),
            uint8(IDCAStrategyManager.Status.COMPLETED),
            "Strategy should auto-transition to COMPLETED on endDate"
        );
    }

    function test_Execute_RevertsOnPriceAboveCeiling() public {
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        // Mocked inPrice=1e8 (USDC/USD, 8 dec) and outPrice=3000e8 (ETH/USD,
        // 8 dec) ⇒ executionPrice = (3000e8 * 1e8 * 1e18) / (1e8 * 1e8) = 3000e18.
        // Ceiling of 2500e18 (USDC per ETH) forces PriceAboveCeiling.
        cfg.maxPrice = uint256(2500e18);
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        vm.warp(block.timestamp + 7 days);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.PriceAboveCeiling.selector,
                uint256(3000e18),
                uint256(2500e18)
            )
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_RevertsOnPriceBelowFloor() public {
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        // executionPrice = 3000e18 (see ceiling test). Floor of 4000e18 (USDC
        // per ETH) forces PriceBelowFloor.
        cfg.minPrice = uint256(4000e18);
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        vm.warp(block.timestamp + 7 days);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.PriceBelowFloor.selector,
                uint256(3000e18),
                uint256(4000e18)
            )
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_RevertsOnOraclePriceZero() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);
        // Override the post-warp mocks: in-feed returns 0 ⇒ OraclePriceZero.
        _mockOracles(int256(0), int256(3000e8));

        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(keeper);
        vm.expectRevert(ChainlinkOracleUtils.ChainlinkOraclePriceZero.selector);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_RevertsOnSwapOutputBelowMinOut() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        // Reconfigure the mock router to deliver a vanishingly small target
        // amount that falls under the slippage-derived minOut.
        ensoRouter.setSwap(
            IERC20(address(sourceFleet)),
            100e6,
            IERC20(WETH_ADDRESS),
            1, // 1 wei of WETH — well below minOut
            targetFleet
        );

        vm.warp(block.timestamp + 7 days);

        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(keeper);
        // Selector-only match (bytes4 form) — the (minOut, actualOut) values
        // are dynamic and we just want to pin the right error path.
        vm.expectPartialRevert(
            IDCAStrategyManagerErrors.SwapOutputBelowMinOut.selector
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_RevertsOnExecutionWindowNotReached() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        // Do NOT warp — nextTriggerAt is hourAligned + interval > now.
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);

        vm.prank(keeper);
        // Selector-only match — ExecutionWindowNotReached carries dynamic
        // timestamps we don't want to pin.
        vm.expectPartialRevert(
            IDCAStrategyManagerErrors.ExecutionWindowNotReached.selector
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_RevertsOnSwapFailed() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        // Replace the router bytecode with `0xfd` (REVERT) so any call lands
        // on success=false. Simpler than vm.mockCallRevert which has ambiguous
        // overloads in this forge-std version.
        vm.etch(address(ensoRouter), hex"fd");

        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(keeper);
        vm.expectRevert(EnsoRouterSwapper.SwapFailed.selector);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_CheckUpkeep_ReturnsFalseOnPriceOutOfBounds() public {
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        // executionPrice = 3000e18; ceiling at 2500e18 ⇒ upkeep must be false.
        cfg.maxPrice = uint256(2500e18);
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        vm.warp(block.timestamp + 7 days);

        (bool upkeepNeeded, ) = dcaManager.checkUpkeep(strategyId, cfg);
        assertFalse(
            upkeepNeeded,
            "Upkeep must be false when execution price is outside guardrails"
        );
    }

    function test_CheckUpkeep_ReturnsFalseAfterMaxTradesReached() public {
        // Execute the one allowed trade so the strategy auto-completes, then
        // verify that checkUpkeep correctly returns false.
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        cfg.maxTrades = 1;
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        vm.warp(block.timestamp + 7 days);
        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");

        vm.warp(block.timestamp + 7 days);
        (bool upkeepNeeded, ) = dcaManager.checkUpkeep(strategyId, cfg);
        assertFalse(
            upkeepNeeded,
            "Upkeep should be false after maxTrades exhausted"
        );
    }

    function _createStrategy(uint256 endDate) internal returns (uint256) {
        vm.startPrank(strategyOwner);
        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            endDate
        );
        uint256 strategyId = dcaManager.createStrategy(config);
        vm.stopPrank();
        return strategyId;
    }

    function _buildConfig(
        uint256 endDate
    ) internal view returns (IDCAStrategyManager.StrategyConfig memory) {
        return
            IDCAStrategyManager.StrategyConfig({
                owner: strategyOwner,
                sourceVault: sourceFleet,
                targetVault: targetFleet,
                inAsset: IERC20(USDC_ADDRESS),
                outAsset: IERC20(WETH_ADDRESS),
                inAssetFeed: address(inFeedMock),
                outAssetFeed: address(outFeedMock),
                tradeAmount: 100e6,
                interval: 7 days,
                slippageBps: 50,
                maxPrice: 0,
                minPrice: 0,
                endDate: endDate,
                maxTrades: 100
            });
    }

    // =========================================================
    // executeStrategy — additional paths
    // =========================================================

    function test_Execute_RevertsWhenPaused() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);
        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            endDate
        );

        vm.prank(strategyOwner);
        dcaManager.pauseStrategy(strategyId, config);

        vm.warp(block.timestamp + 7 days);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                IDCAStrategyManagerErrors.StrategyNotActive.selector,
                strategyId
            )
        );
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");
    }

    function test_Execute_SucceedsAfterResume() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);
        IDCAStrategyManager.StrategyConfig memory config = _buildConfig(
            endDate
        );

        vm.startPrank(strategyOwner);
        dcaManager.pauseStrategy(strategyId, config);
        vm.warp(block.timestamp + 30 days);
        dcaManager.resumeStrategy(strategyId, config);
        vm.stopPrank();

        // After resume: nextTriggerAt = block.timestamp + interval. Warp past it.
        vm.warp(block.timestamp + 7 days + 1);

        uint256 sharesBefore = IERC20(address(targetFleet)).balanceOf(
            strategyOwner
        );
        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, config, hex"deadbeef");

        assertGt(
            IERC20(address(targetFleet)).balanceOf(strategyOwner),
            sharesBefore,
            "Owner should receive target shares after resume + execute"
        );
    }

    function test_Execute_MultipleExecutionsIncrementTradesExecuted() public {
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        cfg.maxTrades = 3;
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        for (uint256 i = 1; i <= 3; i++) {
            vm.warp(block.timestamp + 7 days);
            vm.prank(keeper);
            dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
            assertEq(dcaManager.strategyStates(strategyId).tradesExecuted, i);
        }

        assertEq(
            uint8(dcaManager.strategyStates(strategyId).status),
            uint8(IDCAStrategyManager.Status.COMPLETED),
            "Strategy should be COMPLETED after maxTrades executions"
        );
    }

    function test_Execute_EmitsExecutionCompleted() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);

        vm.warp(block.timestamp + 7 days);

        // Only pin strategyId (topic1); other fields are dynamic.
        vm.prank(keeper);
        vm.expectEmit(true, false, false, false, address(dcaManager));
        emit IDCAStrategyManagerEvents.ExecutionCompleted(
            strategyId,
            0,
            0,
            0,
            0,
            0,
            0
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_EmitsExecutionCompletedWithAssetAmounts() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);

        vm.warp(block.timestamp + 7 days);

        uint256 expectedInAssets = sourceFleet.convertToAssets(cfg.tradeAmount);

        vm.recordLogs();
        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256(
            "ExecutionCompleted(uint256,uint256,uint256,uint256,uint256,uint256,uint256)"
        );
        bool found;
        for (uint256 i; i < logs.length; i++) {
            if (
                logs[i].topics.length > 0 &&
                logs[i].topics[0] == sig &&
                logs[i].emitter == address(dcaManager)
            ) {
                (
                    uint256 tradesExecuted,
                    uint256 inShares,
                    uint256 outShares,
                    uint256 inAssets,
                    uint256 outAssets,
                    uint256 nextTriggerAt
                ) = abi.decode(
                        logs[i].data,
                        (uint256, uint256, uint256, uint256, uint256, uint256)
                    );

                assertEq(tradesExecuted, 1);
                assertEq(
                    inShares,
                    cfg.tradeAmount,
                    "inShares must equal tradeAmount"
                );
                assertGt(
                    outShares,
                    0,
                    "outShares must be non-zero on a successful swap"
                );
                assertEq(
                    inAssets,
                    expectedInAssets,
                    "inAssets must equal sourceVault.convertToAssets(tradeAmount)"
                );
                assertGt(outAssets, 0, "outAssets must be non-zero post-swap");
                assertGt(
                    nextTriggerAt,
                    block.timestamp,
                    "next trigger is in the future"
                );

                found = true;
                break;
            }
        }
        assertTrue(found, "ExecutionCompleted log not emitted");
    }

    function test_Execute_RevertsOnAmountOverflowsUint160() public {
        // tradeAmount above uint160 max is accepted by createStrategy but must
        // revert with AmountOverflowsUint160 when _pullFunds is reached.
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        cfg.tradeAmount = uint256(type(uint160).max) + 1;

        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        vm.warp(block.timestamp + 7 days);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.AmountOverflowsUint160.selector,
                cfg.tradeAmount
            )
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_RevertsOnOutOraclePriceZero() public {
        // Complement to test_Execute_RevertsOnOraclePriceZero which tests the
        // in-asset feed. This test covers the out-asset feed returning 0.
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);
        _mockOracles(int256(1e8), int256(0)); // out-asset feed returns 0

        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(keeper);
        vm.expectRevert(ChainlinkOracleUtils.ChainlinkOraclePriceZero.selector);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_CompletesWhenEndDateInPast() public {
        // Strategy is ACTIVE but its endDate is already in the past (no execution
        // has occurred). The pre-flight endDate guard must emit StrategyCompleted
        // and return gracefully rather than reverting.
        uint256 endDate = block.timestamp + 1 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        // Warp past both endDate and nextTriggerAt (hourAligned + 7 days).
        vm.warp(block.timestamp + 8 days);

        vm.expectEmit(true, false, false, true, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyCompleted(
            strategyId,
            "end_date"
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");

        assertEq(
            uint8(dcaManager.strategyStates(strategyId).status),
            uint8(IDCAStrategyManager.Status.COMPLETED),
            "Strategy should be COMPLETED when endDate is in the past"
        );
    }

    function test_Execute_CompletesAfterEditLoweringMaxTrades() public {
        // After executing 2 trades on a maxTrades=3 strategy, the owner edits
        // it down to maxTrades=2. On the next keeper call the status is still
        // ACTIVE but tradesExecuted(2) >= maxTrades(2), so the pre-flight
        // guard must emit StrategyCompleted and return gracefully.
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        cfg.maxTrades = 3;
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        for (uint256 i = 0; i < 2; i++) {
            vm.warp(block.timestamp + 7 days);
            vm.prank(keeper);
            dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
        }
        assertEq(dcaManager.strategyStates(strategyId).tradesExecuted, 2);
        assertEq(
            uint8(dcaManager.strategyStates(strategyId).status),
            uint8(IDCAStrategyManager.Status.ACTIVE)
        );

        IDCAStrategyManager.StrategyConfig memory newCfg = _buildConfig(
            endDate
        );
        newCfg.maxTrades = 2;
        vm.prank(strategyOwner);
        dcaManager.editStrategy(strategyId, cfg, newCfg);

        vm.warp(block.timestamp + 7 days);

        vm.expectEmit(true, false, false, true, address(dcaManager));
        emit IDCAStrategyManagerEvents.StrategyCompleted(
            strategyId,
            "max_trades"
        );

        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, newCfg, hex"deadbeef");

        assertEq(
            uint8(dcaManager.strategyStates(strategyId).status),
            uint8(IDCAStrategyManager.Status.COMPLETED),
            "Strategy should be COMPLETED when tradesExecuted >= maxTrades"
        );
    }

    // =========================================================
    // checkUpkeep — additional paths
    // =========================================================

    function test_CheckUpkeep_ReturnsFalseWhenPriceBelowFloor() public {
        uint256 endDate = block.timestamp + 365 days;
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        // executionPrice = 3000e18; floor = 4000e18 → price is below the floor.
        cfg.minPrice = uint256(4000e18);
        vm.prank(strategyOwner);
        uint256 strategyId = dcaManager.createStrategy(cfg);

        vm.warp(block.timestamp + 7 days);

        (bool upkeepNeeded, ) = dcaManager.checkUpkeep(strategyId, cfg);
        assertFalse(
            upkeepNeeded,
            "Upkeep must be false when price is below minPrice floor"
        );
    }

    // =========================================================
    // Chainlink oracle staleness checks
    // =========================================================

    /// @dev Overrides `updatedAt` for both feeds via vm.mockCall, bypassing
    /// the MockChainlinkFeed contract's dynamic block.timestamp return. Used
    /// only in staleness-specific tests.
    function _mockOraclesWithUpdatedAt(
        int256 inPrice,
        int256 outPrice,
        uint256 inUpdatedAt,
        uint256 outUpdatedAt
    ) internal {
        vm.mockCall(
            address(inFeedMock),
            abi.encodeWithSelector(
                AggregatorV3Interface.latestRoundData.selector
            ),
            abi.encode(uint80(1), inPrice, uint256(0), inUpdatedAt, uint80(1))
        );
        vm.mockCall(
            address(inFeedMock),
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(uint8(8))
        );
        vm.mockCall(
            address(outFeedMock),
            abi.encodeWithSelector(
                AggregatorV3Interface.latestRoundData.selector
            ),
            abi.encode(uint80(1), outPrice, uint256(0), outUpdatedAt, uint80(1))
        );
        vm.mockCall(
            address(outFeedMock),
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(uint8(8))
        );
    }

    function test_Execute_RevertsOnStaleInFeed() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        // in-feed is stale: updatedAt is one second beyond the staleness window.
        uint256 staleUpdatedAt = block.timestamp -
            ChainlinkOracleUtils.MAX_ORACLE_STALENESS -
            1;
        _mockOraclesWithUpdatedAt(
            int256(1e8),
            int256(3000e8),
            staleUpdatedAt,
            block.timestamp
        );

        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkOracleUtils.ChainlinkOracleStalePrice.selector,
                address(inFeedMock),
                staleUpdatedAt,
                block.timestamp
            )
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_RevertsOnStaleOutFeed() public {
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        // out-feed is stale; in-feed is fresh.
        uint256 staleUpdatedAt = block.timestamp -
            ChainlinkOracleUtils.MAX_ORACLE_STALENESS -
            1;
        _mockOraclesWithUpdatedAt(
            int256(1e8),
            int256(3000e8),
            block.timestamp,
            staleUpdatedAt
        );

        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkOracleUtils.ChainlinkOracleStalePrice.selector,
                address(outFeedMock),
                staleUpdatedAt,
                block.timestamp
            )
        );
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    function test_Execute_SucceedsWhenFeedsAreExactlyAtStalenessLimit() public {
        // updatedAt == block.timestamp - MAX_ORACLE_STALENESS should NOT revert
        // (boundary: > staleness reverts, == staleness is still fresh).
        uint256 endDate = block.timestamp + 365 days;
        uint256 strategyId = _createStrategy(endDate);

        vm.warp(block.timestamp + 7 days);

        uint256 exactBoundary = block.timestamp -
            ChainlinkOracleUtils.MAX_ORACLE_STALENESS;
        _mockOraclesWithUpdatedAt(
            int256(1e8),
            int256(3000e8),
            exactBoundary,
            exactBoundary
        );

        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
    }

    // =========================================================
    // Permit2-signature entrypoints
    // =========================================================

    uint256 private constant _SIGNER_PK = 0xA11CE;

    bytes32 private constant _PERMIT_DETAILS_TYPEHASH =
        keccak256(
            "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
        );
    bytes32 private constant _PERMIT_SINGLE_TYPEHASH =
        keccak256(
            "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
        );
    bytes32 private constant _TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 private constant _PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

    function _signPermit2Single(
        IAllowanceTransfer.PermitSingle memory permitSingle,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 detailsHash = keccak256(
            abi.encode(
                _PERMIT_DETAILS_TYPEHASH,
                permitSingle.details.token,
                permitSingle.details.amount,
                permitSingle.details.expiration,
                permitSingle.details.nonce
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_SINGLE_TYPEHASH,
                detailsHash,
                permitSingle.spender,
                permitSingle.sigDeadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IPermit2(PERMIT2).DOMAIN_SEPARATOR(),
                structHash
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signPermit2Transfer(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TRANSFER_FROM_TYPEHASH,
                keccak256(
                    abi.encode(
                        _TOKEN_PERMISSIONS_TYPEHASH,
                        permit.permitted.token,
                        permit.permitted.amount
                    )
                ),
                spender,
                permit.nonce,
                permit.deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IPermit2(PERMIT2).DOMAIN_SEPARATOR(),
                structHash
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Sets up a signer-backed user with USDC, source-vault shares, and
    /// the one-time approvals required for both Permit2 paths. Returns the
    /// signer address.
    function _setupSigner() internal returns (address signer) {
        signer = vm.addr(_SIGNER_PK);

        deal(USDC_ADDRESS, signer, 10000e6);

        vm.startPrank(signer);
        // Standard one-time ERC20 approvals to Permit2.
        IERC20(USDC_ADDRESS).approve(PERMIT2, type(uint256).max);
        IERC20(address(sourceFleet)).approve(PERMIT2, type(uint256).max);
        // Deposit some USDC into the source vault so the signer holds shares
        // (used by createStrategyWithPermit and the keeper-execution path).
        IERC20(USDC_ADDRESS).approve(address(sourceFleet), type(uint256).max);
        sourceFleet.deposit(1000e6, signer);
        vm.stopPrank();
    }

    function _buildConfigFor(
        address ownerAddr,
        uint256 endDate
    ) internal view returns (IDCAStrategyManager.StrategyConfig memory) {
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfig(endDate);
        cfg.owner = ownerAddr;
        return cfg;
    }

    function test_CreateStrategyWithPermit2_HappyPath() public {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: address(sourceFleet),
                    amount: type(uint160).max,
                    expiration: type(uint48).max,
                    nonce: 0
                }),
                spender: address(dcaManager),
                sigDeadline: block.timestamp + 1 hours
            });
        bytes memory sig = _signPermit2Single(permitSingle, _SIGNER_PK);

        vm.prank(signer);
        uint256 strategyId = dcaManager.createStrategyWithPermit2(
            cfg,
            permitSingle,
            sig
        );

        assertEq(strategyId, 0, "first strategy gets id 0");
        assertEq(
            uint8(dcaManager.strategyStates(strategyId).status),
            uint8(IDCAStrategyManager.Status.ACTIVE)
        );
        (uint160 allowanceAmount, uint48 allowanceExpiration, ) = IPermit2(
            PERMIT2
        ).allowance(signer, address(sourceFleet), address(dcaManager));
        assertEq(allowanceAmount, type(uint160).max, "sub-allowance set");
        assertEq(allowanceExpiration, type(uint48).max, "expiration as signed");
    }

    function test_CreateStrategyWithPermit2_AllowsKeeperToPull() public {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: address(sourceFleet),
                    amount: type(uint160).max,
                    expiration: type(uint48).max,
                    nonce: 0
                }),
                spender: address(dcaManager),
                sigDeadline: block.timestamp + 1 hours
            });
        bytes memory sig = _signPermit2Single(permitSingle, _SIGNER_PK);

        vm.prank(signer);
        uint256 strategyId = dcaManager.createStrategyWithPermit2(
            cfg,
            permitSingle,
            sig
        );

        // Pre-fund the mock router for this signer's swap, since _setupUser
        // wired it only for `strategyOwner`-sourced shares.
        deal(WETH_ADDRESS, address(ensoRouter), 100 ether);
        ensoRouter.setSwap(
            IERC20(address(sourceFleet)),
            100e6,
            IERC20(WETH_ADDRESS),
            MOCK_WETH_OUT,
            targetFleet
        );

        vm.warp(block.timestamp + 7 days);
        uint256 sharesBefore = IERC20(address(targetFleet)).balanceOf(signer);
        vm.prank(keeper);
        dcaManager.executeStrategy(strategyId, cfg, hex"deadbeef");
        assertGt(
            IERC20(address(targetFleet)).balanceOf(signer),
            sharesBefore,
            "keeper pulled via the Permit2-set sub-allowance"
        );
    }

    function test_CreateStrategyWithPermit2_RevertsOnWrongSpender() public {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: address(sourceFleet),
                    amount: type(uint160).max,
                    expiration: type(uint48).max,
                    nonce: 0
                }),
                spender: address(0xBEEF),
                sigDeadline: block.timestamp + 1 hours
            });
        bytes memory sig = _signPermit2Single(permitSingle, _SIGNER_PK);

        vm.prank(signer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.InvalidPermit2Spender.selector,
                address(dcaManager),
                address(0xBEEF)
            )
        );
        dcaManager.createStrategyWithPermit2(cfg, permitSingle, sig);
    }

    function test_CreateStrategyWithPermit2_RevertsOnWrongToken() public {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: USDC_ADDRESS,
                    amount: type(uint160).max,
                    expiration: type(uint48).max,
                    nonce: 0
                }),
                spender: address(dcaManager),
                sigDeadline: block.timestamp + 1 hours
            });
        bytes memory sig = _signPermit2Single(permitSingle, _SIGNER_PK);

        vm.prank(signer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.InvalidPermit2Token.selector,
                address(sourceFleet),
                USDC_ADDRESS
            )
        );
        dcaManager.createStrategyWithPermit2(cfg, permitSingle, sig);
    }

    function test_CreateStrategyWithPermit2_SurvivesFrontrunOfPermit() public {
        // If a mempool searcher lifts the user's signed PermitSingle and
        // submits PERMIT2.permit themselves, the user's createStrategyWithPermit2
        // call should still succeed (the sub-allowance is live, so the silent
        // try/catch path inside _applyPermit2Allowance allows it through).
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: address(sourceFleet),
                    amount: type(uint160).max,
                    expiration: type(uint48).max,
                    nonce: 0
                }),
                spender: address(dcaManager),
                sigDeadline: block.timestamp + 1 hours
            });
        bytes memory sig = _signPermit2Single(permitSingle, _SIGNER_PK);

        // Front-run: any address submits the signed permit directly.
        vm.prank(address(0xF20E));
        IPermit2(PERMIT2).permit(signer, permitSingle, sig);

        // User's tx now reaches PERMIT2.permit with a stale nonce — internal
        // try/catch must verify the existing allowance and let the flow
        // continue without reverting.
        vm.prank(signer);
        uint256 strategyId = dcaManager.createStrategyWithPermit2(
            cfg,
            permitSingle,
            sig
        );
        assertEq(strategyId, 0, "frontrun must not block strategy creation");
    }

    function test_DepositAndCreateWithPermit2_HappyPath() public {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );
        uint256 depositAmount = 500e6;

        IDCAStrategyManager.Permit2DepositBundle
            memory permits = IDCAStrategyManager.Permit2DepositBundle({
                inAsset: ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({
                        token: IERC20(USDC_ADDRESS),
                        amount: depositAmount
                    }),
                    nonce: 1,
                    deadline: block.timestamp + 1 hours
                }),
                inAssetSig: bytes(""),
                shares: IAllowanceTransfer.PermitSingle({
                    details: IAllowanceTransfer.PermitDetails({
                        token: address(sourceFleet),
                        amount: type(uint160).max,
                        expiration: type(uint48).max,
                        nonce: 0
                    }),
                    spender: address(dcaManager),
                    sigDeadline: block.timestamp + 1 hours
                }),
                sharesSig: bytes("")
            });
        permits.inAssetSig = _signPermit2Transfer(
            permits.inAsset,
            address(dcaManager),
            _SIGNER_PK
        );
        permits.sharesSig = _signPermit2Single(permits.shares, _SIGNER_PK);

        uint256 sharesBefore = sourceFleet.balanceOf(signer);
        uint256 usdcBefore = IERC20(USDC_ADDRESS).balanceOf(signer);

        vm.prank(signer);
        uint256 strategyId = dcaManager.depositAndCreateWithPermit2(
            cfg,
            depositAmount,
            permits
        );

        assertEq(strategyId, 0);
        assertEq(
            uint8(dcaManager.strategyStates(strategyId).status),
            uint8(IDCAStrategyManager.Status.ACTIVE)
        );
        assertGt(
            sourceFleet.balanceOf(signer),
            sharesBefore,
            "user received source-vault shares"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(signer),
            usdcBefore - depositAmount,
            "user's USDC debited"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(dcaManager)),
            0,
            "manager holds no USDC"
        );
        (uint160 allowanceAmount, , ) = IPermit2(PERMIT2).allowance(
            signer,
            address(sourceFleet),
            address(dcaManager)
        );
        assertEq(
            allowanceAmount,
            type(uint160).max,
            "shares sub-allowance set"
        );
    }

    function test_DepositAndCreateWithPermit2_RevertsOnSharesSpenderMismatch()
        public
    {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );
        uint256 depositAmount = 500e6;

        IDCAStrategyManager.Permit2DepositBundle memory permits;
        permits.inAsset = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: IERC20(USDC_ADDRESS),
                amount: depositAmount
            }),
            nonce: 1,
            deadline: block.timestamp + 1 hours
        });
        permits.shares = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(sourceFleet),
                amount: type(uint160).max,
                expiration: type(uint48).max,
                nonce: 0
            }),
            // Wrong spender — not the manager.
            spender: address(0xBEEF),
            sigDeadline: block.timestamp + 1 hours
        });
        permits.inAssetSig = _signPermit2Transfer(
            permits.inAsset,
            address(dcaManager),
            _SIGNER_PK
        );
        permits.sharesSig = _signPermit2Single(permits.shares, _SIGNER_PK);

        vm.prank(signer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.InvalidPermit2Spender.selector,
                address(dcaManager),
                address(0xBEEF)
            )
        );
        dcaManager.depositAndCreateWithPermit2(cfg, depositAmount, permits);
    }

    function test_DepositAndCreateWithPermit2_RevertsOnSharesTokenMismatch()
        public
    {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );
        uint256 depositAmount = 500e6;

        IDCAStrategyManager.Permit2DepositBundle memory permits;
        permits.inAsset = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: IERC20(USDC_ADDRESS),
                amount: depositAmount
            }),
            nonce: 1,
            deadline: block.timestamp + 1 hours
        });
        // Wrong shares token — points at USDC, not the source-vault share token.
        permits.shares = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: USDC_ADDRESS,
                amount: type(uint160).max,
                expiration: type(uint48).max,
                nonce: 0
            }),
            spender: address(dcaManager),
            sigDeadline: block.timestamp + 1 hours
        });
        permits.inAssetSig = _signPermit2Transfer(
            permits.inAsset,
            address(dcaManager),
            _SIGNER_PK
        );
        permits.sharesSig = _signPermit2Single(permits.shares, _SIGNER_PK);

        vm.prank(signer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.InvalidPermit2Token.selector,
                address(sourceFleet),
                USDC_ADDRESS
            )
        );
        dcaManager.depositAndCreateWithPermit2(cfg, depositAmount, permits);
    }

    function test_DepositAndCreateWithPermit2_RevertsOnInAssetTokenMismatch()
        public
    {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );
        uint256 depositAmount = 500e6;

        IDCAStrategyManager.Permit2DepositBundle memory permits;
        // Wrong inAsset token — points at WETH instead of USDC.
        permits.inAsset = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: IERC20(WETH_ADDRESS),
                amount: depositAmount
            }),
            nonce: 1,
            deadline: block.timestamp + 1 hours
        });
        permits.shares = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(sourceFleet),
                amount: type(uint160).max,
                expiration: type(uint48).max,
                nonce: 0
            }),
            spender: address(dcaManager),
            sigDeadline: block.timestamp + 1 hours
        });
        permits.inAssetSig = _signPermit2Transfer(
            permits.inAsset,
            address(dcaManager),
            _SIGNER_PK
        );
        permits.sharesSig = _signPermit2Single(permits.shares, _SIGNER_PK);

        vm.prank(signer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.InvalidPermit2Token.selector,
                USDC_ADDRESS,
                WETH_ADDRESS
            )
        );
        dcaManager.depositAndCreateWithPermit2(cfg, depositAmount, permits);
    }

    function test_DepositAndCreateWithPermit2_RevertsOnInAssetAmountMismatch()
        public
    {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );
        uint256 depositAmount = 500e6;

        IDCAStrategyManager.Permit2DepositBundle memory permits;
        // Signed amount differs from requested amount by 1 wei.
        permits.inAsset = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: IERC20(USDC_ADDRESS),
                amount: depositAmount + 1
            }),
            nonce: 1,
            deadline: block.timestamp + 1 hours
        });
        permits.shares = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(sourceFleet),
                amount: type(uint160).max,
                expiration: type(uint48).max,
                nonce: 0
            }),
            spender: address(dcaManager),
            sigDeadline: block.timestamp + 1 hours
        });
        permits.inAssetSig = _signPermit2Transfer(
            permits.inAsset,
            address(dcaManager),
            _SIGNER_PK
        );
        permits.sharesSig = _signPermit2Single(permits.shares, _SIGNER_PK);

        vm.prank(signer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Permit2Consumer.InvalidPermit2Amount.selector,
                depositAmount,
                depositAmount + 1
            )
        );
        dcaManager.depositAndCreateWithPermit2(cfg, depositAmount, permits);
    }

    function test_DepositAndCreateWithPermit2_RevertsOnZeroDeposit() public {
        address signer = _setupSigner();
        IDCAStrategyManager.StrategyConfig memory cfg = _buildConfigFor(
            signer,
            block.timestamp + 365 days
        );
        IDCAStrategyManager.Permit2DepositBundle memory permits; // all zeroed

        vm.prank(signer);
        vm.expectRevert(IDCAStrategyManagerErrors.ZeroDeposit.selector);
        dcaManager.depositAndCreateWithPermit2(cfg, 0, permits);
    }
}
