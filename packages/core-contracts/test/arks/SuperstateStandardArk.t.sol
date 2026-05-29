// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/SuperstateStandardArk.sol";
import {AggregatorV3Interface} from "../../src/interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {ISuperstateArkErrors} from "../../src/errors/arks/ISuperstateArkErrors.sol";
import {ISuperstateStandardArkErrors} from "../../src/errors/arks/ISuperstateStandardArkErrors.sol";
import {ISuperstateStandardArk} from "../../src/interfaces/arks/ISuperstateStandardArk.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {AssetsForwarder} from "../../src/utils/AssetsForwarder/AssetsForwarder.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

// Dummy mock for Chainlink Oracle
contract MockSuperstateOracle is AggregatorV3Interface {
    uint8 public _decimals;
    int256 public _answer;

    uint80 public _roundId = 1;
    uint256 public _updatedAt;
    uint80 public _answeredInRound = 1;

    constructor(uint8 decimals_, int256 answer_) {
        _decimals = decimals_;
        _answer = answer_;
        _updatedAt = block.timestamp;
    }

    function setAnswer(int256 newAnswer) external {
        _answer = newAnswer;
        _updatedAt = block.timestamp;
    }

    function setRoundData(
        uint80 roundId,
        int256 answer,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        _roundId = roundId;
        _answer = answer;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }

    function description() external view override returns (string memory) {
        return "MockOracle";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }
}

contract SuperstateStandardArkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    using SafeERC20 for IERC20;

    event CustodianWalletUpdated(address oldWallet, address newWallet);
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);

    SuperstateStandardArk public ark;
    BufferArk public bufferArk;
    IERC20 public usdc;
    MockERC20 public shareToken;
    MockSuperstateOracle public oracle;

    address depositAddress = address(0x1111);

    ArkParams public params;

    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 forkBlock = 21666256;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        keeper = makeAddr("keeper");

        shareToken = new MockERC20();
        shareToken.initialize("USTB", "USTB", 6);

        oracle = new MockSuperstateOracle(8, 10 * 1e8);

        params = ArkParams({
            name: "USDC Superstate Ark",
            details: "USDC Superstate Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.startPrank(governor);
        Percentage sweepSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);
        Percentage depositSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);
        ark = new SuperstateStandardArk(
            address(shareToken),
            depositAddress,
            address(oracle),
            sweepSlippage,
            depositSlippage,
            params
        );
        vm.stopPrank();

        ArkParams memory bParams = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        bufferArk = new BufferArk(bParams, address(commander));

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        accessManager.grantKeeperRole(address(ark), keeper);

        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor() public {
        vm.expectRevert(ISuperstateArkErrors.InvalidShareTokenAddress.selector);
        new SuperstateStandardArk(
            address(0),
            depositAddress,
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );

        vm.expectRevert(
            ISuperstateStandardArkErrors.InvalidDepositAddress.selector
        );
        new SuperstateStandardArk(
            address(shareToken),
            address(0),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );

        vm.expectRevert(ISuperstateArkErrors.InvalidOracleAddress.selector);
        new SuperstateStandardArk(
            address(shareToken),
            depositAddress,
            address(0),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );

        assertEq(address(ark.asset()), USDC_ADDRESS, "Asset should match");
    }

    function test_Board_And_PendingDeposit() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 initialTargetBalance = usdc.balanceOf(depositAddress);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalTargetBalance = usdc.balanceOf(depositAddress);
        assertEq(
            finalTargetBalance,
            initialTargetBalance + amount,
            "Target contract should receive tokens"
        );
        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets should match boarded amount (pending deposit)"
        );
        assertEq(
            ark.pendingDepositAssets(),
            amount,
            "Pending deposit should match"
        );
    }

    function test_ClearPendingDeposit() public {
        // 1. Board
        uint256 amount = 10 * 1e6; // Exact price of 1 share
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // 2. Shares arrive off-chain
        uint256 sharesMinted = 1e6; // 1 USTB (6 decimals)
        shareToken.mint(address(ark), sharesMinted);

        // 3. Keep clears
        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        assertEq(
            ark.pendingDepositAssets(),
            0,
            "Pending deposit should be cleared"
        );
        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets should perfectly transition to oracle share value"
        );
    }

    function test_RequestWithdrawal_And_Sweep() public {
        // 1. Setup fully cleared deposit
        uint256 amount = 10 * 1e6; // 1 share worth
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e6; // 1 share
        shareToken.mint(address(ark), sharesMinted);

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();

        // Verify initial state
        assertEq(ark.totalAssets(), amount);

        // 2. Request Withdrawal — offchainRedeem burns shares from the Ark
        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature(
                "offchainRedeem(uint256)",
                sharesMinted
            ),
            abi.encode()
        );

        vm.startPrank(keeper);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // Simulate the burn that offchainRedeem would perform (mock is a no-op)
        deal(address(shareToken), address(ark), 0);

        // offchainRedeem was called (mocked) — shares are burned, not transferred
        assertEq(
            ark.pendingWithdrawalShares(),
            sharesMinted,
            "Pending withdrawal tracks shares"
        );
        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets remains stable during withdrawal"
        );

        // The swept USDC goes to the Ark now from the redeem process
        deal(USDC_ADDRESS, address(ark), amount);

        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );

        vm.startPrank(keeper);
        ark.sweep();
        vm.stopPrank();

        assertEq(
            ark.pendingWithdrawalShares(),
            0,
            "Pending withdrawal cleared"
        );
        assertEq(
            ark.totalAssets(),
            0,
            "Total assets drops to 0 after sweep sends USDC away"
        );
        assertEq(usdc.balanceOf(address(ark)), 0, "Ark has 0 USDC");
    }

    function test_ZeroAmountTransfers() public {
        vm.startPrank(address(commander));

        // board(0) should increase pendingDepositAssets by 0 and not revert.
        ark.board(0, bytes(""));
        assertEq(ark.pendingDepositAssets(), 0, "pending deposit assets");

        // Request withdrawal of 0
        vm.stopPrank();

        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature("offchainRedeem(uint256)", uint256(0)),
            abi.encode()
        );

        vm.startPrank(keeper);
        ark.requestWithdrawal(0);
        vm.stopPrank();

        // disembark(0)
        vm.startPrank(address(commander));
        ark.disembark(0, new bytes(0));
        vm.stopPrank();

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        vm.stopPrank();
    }

    /* Stacked-Withdrawal Guard (Pashov audit #3 fix ported from WisdomTreeArk) */

    function test_RequestWithdrawal_RevertsIfPendingWithdrawal() public {
        // Set up a fully cleared deposit
        uint256 amount = 10 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e6;
        shareToken.mint(address(ark), sharesMinted);

        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature("offchainRedeem(uint256)", sharesMinted),
            abi.encode()
        );

        vm.startPrank(keeper);
        ark.clearPendingDeposit();

        // First withdrawal queues fine
        ark.requestWithdrawal(amount);

        // Second withdrawal must revert because a cycle is in flight
        vm.expectRevert(
            ISuperstateArkErrors.PendingWithdrawalActive.selector
        );
        ark.requestWithdrawal(amount);
        vm.stopPrank();
    }

    /* Freeze gates sweep too (ported from WisdomTreeArk) */

    function test_RevertSweepWhenFrozen() public {
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        vm.startPrank(keeper);
        vm.expectRevert(
            ISuperstateStandardArkErrors.ArkIsFrozen.selector
        );
        ark.sweep();
        vm.stopPrank();
    }

    function test_RevertBoardWhenFrozen() public {
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(
            ISuperstateStandardArkErrors.ArkIsFrozen.selector
        );
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_RevertRequestWithdrawalWhenFrozen() public {
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        vm.startPrank(keeper);
        vm.expectRevert(
            ISuperstateStandardArkErrors.ArkIsFrozen.selector
        );
        ark.requestWithdrawal(1000 * 1e6);
        vm.stopPrank();
    }

    /* Emergency Sweep (inherited from BaseSuperstateArk) */

    function test_EmergencySweep_RevertsIfNotGovernor() public {
        vm.startPrank(keeper);
        vm.expectRevert();
        ark.emergencySweep();
        vm.stopPrank();
    }

    function test_EmergencySweep_BypassesSweepSlippage() public {
        // Set up an active withdrawal cycle with a return below the slippage band
        uint256 amount = 10 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e6;
        shareToken.mint(address(ark), sharesMinted);

        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature("offchainRedeem(uint256)", sharesMinted),
            abi.encode()
        );

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // Simulate Superstate returning far less than expected (5 USDC vs ~10 expected)
        uint256 returnedUsdc = 5 * 1e6;
        deal(USDC_ADDRESS, address(ark), returnedUsdc);

        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );

        // Keeper sweep would revert (below the 0.5% slippage band)
        vm.startPrank(keeper);
        vm.expectRevert();
        ark.sweep();
        vm.stopPrank();

        // Governor emergencySweep succeeds and forwards whatever USDC is on the ark
        vm.startPrank(governor);
        ark.emergencySweep();
        vm.stopPrank();

        assertEq(
            ark.pendingWithdrawalShares(),
            0,
            "pendingWithdrawalShares cleared by emergencySweep"
        );
        assertEq(
            usdc.balanceOf(address(bufferArk)),
            returnedUsdc,
            "Buffer ark received the partial return"
        );
    }

    function test_EmergencySweep_WorksWhenFrozen() public {
        // Freeze first
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        // Drop some USDC on the ark (no pending withdrawal needed for this path)
        uint256 returnedUsdc = 1e6;
        deal(USDC_ADDRESS, address(ark), returnedUsdc);

        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );

        // Keeper sweep is blocked by the freeze
        vm.startPrank(keeper);
        vm.expectRevert(
            ISuperstateStandardArkErrors.ArkIsFrozen.selector
        );
        ark.sweep();
        vm.stopPrank();

        // Governor emergencySweep still works
        vm.startPrank(governor);
        ark.emergencySweep();
        vm.stopPrank();

        assertEq(
            usdc.balanceOf(address(bufferArk)),
            returnedUsdc,
            "Buffer ark received the swept asset while frozen"
        );
    }

    /* Emergency Clear Pending Deposit */

    function test_EmergencyClearPendingDeposit_RevertsIfNotGovernor() public {
        vm.startPrank(keeper);
        vm.expectRevert();
        ark.emergencyClearPendingDeposit(1);
        vm.stopPrank();
    }

    function test_EmergencyClearPendingDeposit_RescuesPartialFill() public {
        // Board a deposit
        uint256 amount = 100 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Only partial shares arrive (insufficient under the deposit-slippage band)
        uint256 partialShares = 1e6; // would need 10e6 for full clearance at price=10
        shareToken.mint(address(ark), partialShares);

        // Keeper-facing clear fails
        vm.startPrank(keeper);
        vm.expectRevert();
        ark.clearPendingDeposit();
        vm.stopPrank();

        // Governor partially clears the half that did arrive (10 USDC worth)
        uint256 partialAmount = 10 * 1e6;
        vm.prank(governor);
        ark.emergencyClearPendingDeposit(partialAmount);

        assertEq(
            ark.pendingDepositAssets(),
            amount - partialAmount,
            "Pending queue shrinks by cleared amount"
        );
        assertEq(
            ark.cachedShareBalance(),
            partialShares,
            "cachedShareBalance hard-resets to live balance"
        );
    }

    function test_EmergencyClearPendingDeposit_RevertsIfAmountExceedsPending()
        public
    {
        // No pending deposit; any positive amount must revert
        vm.prank(governor);
        vm.expectRevert(
            ISuperstateStandardArkErrors.InsufficientPendingDeposit.selector
        );
        ark.emergencyClearPendingDeposit(1);
    }

    /* L9 cap regression — requestWithdrawal clamps sharesToRedeem to available balance */

    function test_RequestWithdrawal_CapsAtShareBalance() public {
        uint256 sharesAvailable = 1e6;
        shareToken.mint(address(ark), sharesAvailable);

        // _assetsToShares(1000 USDC) = 100 shares — far above the 1-share balance
        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature("offchainRedeem(uint256)"),
            abi.encode()
        );

        uint256 amount = 1000 * 1e6;
        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        assertEq(
            ark.pendingWithdrawalShares(),
            sharesAvailable,
            "pendingWithdrawalShares must be capped at the share balance"
        );
    }

    /* Oracle failure paths */

    function test_RequestWithdrawal_RevertsIfOraclePriceNonPositive() public {
        shareToken.mint(address(ark), 1e6);
        oracle.setAnswer(0);
        vm.prank(keeper);
        vm.expectRevert(ISuperstateArkErrors.OraclePriceNotPositive.selector);
        ark.requestWithdrawal(1e6);
    }

    function test_RequestWithdrawal_RevertsIfOracleStale() public {
        shareToken.mint(address(ark), 1e6);
        oracle.setRoundData(
            1,
            10 * 1e8,
            block.timestamp - 24 hours - 1,
            1
        );
        vm.prank(keeper);
        vm.expectRevert(ISuperstateArkErrors.StaleOraclePrice.selector);
        ark.requestWithdrawal(1e6);
    }

    function test_TotalAssets_RevertsIfOracleStale_WhenSharesPresent() public {
        shareToken.mint(address(ark), 1e6);
        oracle.setRoundData(
            1,
            10 * 1e8,
            block.timestamp - 24 hours - 1,
            1
        );
        vm.expectRevert(ISuperstateArkErrors.StaleOraclePrice.selector);
        ark.totalAssets();
    }

    function test_TotalAssets_DoesNotTouchOracleWhenEmpty() public view {
        // With zero shares and zero pending, totalAssets should short-circuit to 0 without reading the oracle
        assertEq(ark.totalAssets(), 0);
    }

    function test_ClearPendingDeposit_RevertsIfOracleNonPositive() public {
        uint256 amount = 10 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        shareToken.mint(address(ark), 1e6);
        oracle.setAnswer(-1);

        vm.prank(keeper);
        vm.expectRevert(ISuperstateArkErrors.OraclePriceNotPositive.selector);
        ark.clearPendingDeposit();
    }

    /* Slippage cap setters */

    function test_SetSweepSlippage_RevertsAboveMax() public {
        Percentage above = Percentage.wrap(PERCENTAGE_FACTOR / 2 + 1);
        Percentage maxP = ark.MAX_SWEEP_SLIPPAGE();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISuperstateArkErrors.InvalidSweepSlippage.selector,
                above,
                maxP
            )
        );
        ark.setSweepSlippage(above);
    }

    function test_SetSweepSlippage_AcceptsExactMax() public {
        Percentage atMax = ark.MAX_SWEEP_SLIPPAGE();
        vm.prank(keeper);
        ark.setSweepSlippage(atMax);
        assertEq(
            Percentage.unwrap(ark.sweepSlippage()),
            Percentage.unwrap(atMax)
        );
    }

    function test_SetSweepSlippage_RevertsIfNotKeeper() public {
        vm.expectRevert();
        ark.setSweepSlippage(Percentage.wrap(0));
    }

    function test_SetDepositSlippage_RevertsAboveMax() public {
        Percentage above = Percentage.wrap(PERCENTAGE_FACTOR / 2 + 1);
        Percentage maxP = ark.MAX_DEPOSIT_SLIPPAGE();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISuperstateArkErrors.InvalidDepositSlippage.selector,
                above,
                maxP
            )
        );
        ark.setDepositSlippage(above);
    }

    function test_SetDepositSlippage_AcceptsExactMax() public {
        Percentage atMax = ark.MAX_DEPOSIT_SLIPPAGE();
        vm.prank(keeper);
        ark.setDepositSlippage(atMax);
        assertEq(
            Percentage.unwrap(ark.depositSlippage()),
            Percentage.unwrap(atMax)
        );
    }

    function test_SetDepositSlippage_RevertsIfNotKeeper() public {
        vm.expectRevert();
        ark.setDepositSlippage(Percentage.wrap(0));
    }

    function test_Constructor_RevertsIfSweepSlippageAboveMax() public {
        Percentage above = Percentage.wrap(PERCENTAGE_FACTOR / 2 + 1);
        vm.expectRevert();
        new SuperstateStandardArk(
            address(shareToken),
            depositAddress,
            address(oracle),
            above,
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
    }

    function test_Constructor_RevertsIfDepositSlippageAboveMax() public {
        Percentage above = Percentage.wrap(PERCENTAGE_FACTOR / 2 + 1);
        vm.expectRevert();
        new SuperstateStandardArk(
            address(shareToken),
            depositAddress,
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            above,
            params
        );
    }

    /* setArkFrozen paths */

    function test_SetArkFrozen_SnapshotsLiveTotalAssetsWithSentinel() public {
        shareToken.mint(address(ark), 1e6); // 1 share = 10 USDC at mock price
        uint256 live = ark.totalAssets();
        assertEq(live, 10 * 1e6);

        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);

        assertEq(
            ark.totalAssets(),
            live,
            "sentinel must capture live totalAssets()"
        );
    }

    function test_SetArkFrozen_UsesExplicitValue() public {
        uint256 explicitValue = 12345 * 1e6;
        vm.prank(keeper);
        ark.setArkFrozen(true, explicitValue);
        assertEq(ark.totalAssets(), explicitValue);
    }

    function test_SetArkFrozen_TotalAssetsLockedDespiteOracleMove() public {
        shareToken.mint(address(ark), 1e6);
        vm.prank(keeper);
        ark.setArkFrozen(true, type(uint256).max);
        uint256 frozen = ark.totalAssets();

        oracle.setAnswer(100 * 1e8); // 10x price move
        assertEq(
            ark.totalAssets(),
            frozen,
            "frozen totalAssets must ignore oracle moves"
        );
    }

    function test_SetArkFrozen_RefreezeUpdatesSnapshot() public {
        vm.prank(keeper);
        ark.setArkFrozen(true, 100);
        assertEq(ark.totalAssets(), 100);

        vm.prank(keeper);
        ark.setArkFrozen(true, 200);
        assertEq(ark.totalAssets(), 200);
    }

    function test_SetArkFrozen_RevertsIfNotKeeper() public {
        vm.expectRevert();
        ark.setArkFrozen(true, type(uint256).max);
    }

    /* Sweep slippage boundary */

    function test_Sweep_PassesAtExactSlippageBoundary() public {
        uint256 amount = 10 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e6;
        shareToken.mint(address(ark), sharesMinted);

        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature("offchainRedeem(uint256)"),
            abi.encode()
        );

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // Slippage band: pendingMinusSlippage = 1e6 * 0.995 = 995_000 shares.
        // returnedShares = returnedAssets / 10 (mock price). For returnedShares == 995_000, returnedAssets = 9_950_000.
        uint256 returned = 995 * 1e4; // 9.95 USDC — exactly at boundary
        deal(USDC_ADDRESS, address(ark), returned);

        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );

        vm.prank(keeper);
        ark.sweep();
        assertEq(ark.pendingWithdrawalShares(), 0);
    }

    function test_Sweep_RevertsJustBelowSlippageBoundary() public {
        uint256 amount = 10 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 sharesMinted = 1e6;
        shareToken.mint(address(ark), sharesMinted);

        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature("offchainRedeem(uint256)"),
            abi.encode()
        );

        vm.startPrank(keeper);
        ark.clearPendingDeposit();
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // 9.94 USDC — one unit below the 9.95 boundary
        deal(USDC_ADDRESS, address(ark), 994 * 1e4);

        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            address(commander),
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );

        vm.prank(keeper);
        vm.expectRevert();
        ark.sweep();
    }

    /* Fuzz tests */

    function testFuzz_SharesAssetsRoundTrip(uint256 amount) public {
        // 10 wei floor avoids the dust regime where amount<price truncates to 0 shares
        amount = bound(amount, 10, 1_000_000 * 1e6);
        // Mint generous balance so the L9 cap never bites
        shareToken.mint(address(ark), 1_000_000 * 1e6);

        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature("offchainRedeem(uint256)"),
            abi.encode()
        );

        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        // assetsInWithdrawalQueue() = _sharesToAssets(_assetsToShares(amount))
        uint256 roundTrip = ark.assetsInWithdrawalQueue();
        assertLe(roundTrip, amount, "round-trip cannot increase the value");
        // Loss bounded by 1 share's asset-price worth (10 wei in mock setup)
        assertApproxEqAbs(
            roundTrip,
            amount,
            10,
            "round-trip loss exceeds the per-share price"
        );
    }

    function testFuzz_SetSweepSlippage_RespectsMax(uint256 raw) public {
        Percentage maxP = ark.MAX_SWEEP_SLIPPAGE();
        Percentage p = Percentage.wrap(
            bound(raw, 0, Percentage.unwrap(maxP) * 2)
        );
        vm.startPrank(keeper);
        if (Percentage.unwrap(p) > Percentage.unwrap(maxP)) {
            vm.expectRevert();
            ark.setSweepSlippage(p);
        } else {
            ark.setSweepSlippage(p);
            assertEq(
                Percentage.unwrap(ark.sweepSlippage()),
                Percentage.unwrap(p)
            );
        }
        vm.stopPrank();
    }

    function testFuzz_SetDepositSlippage_RespectsMax(uint256 raw) public {
        Percentage maxP = ark.MAX_DEPOSIT_SLIPPAGE();
        Percentage p = Percentage.wrap(
            bound(raw, 0, Percentage.unwrap(maxP) * 2)
        );
        vm.startPrank(keeper);
        if (Percentage.unwrap(p) > Percentage.unwrap(maxP)) {
            vm.expectRevert();
            ark.setDepositSlippage(p);
        } else {
            ark.setDepositSlippage(p);
            assertEq(
                Percentage.unwrap(ark.depositSlippage()),
                Percentage.unwrap(p)
            );
        }
        vm.stopPrank();
    }

    function testFuzz_RequestWithdrawal_CapsAtShareBalance(
        uint256 balance,
        uint256 amount
    ) public {
        balance = bound(balance, 1, 1_000_000 * 1e6);
        amount = bound(amount, 1, 1_000_000_000 * 1e6); // can be far above the share-implied value

        shareToken.mint(address(ark), balance);

        vm.mockCall(
            address(shareToken),
            abi.encodeWithSignature("offchainRedeem(uint256)"),
            abi.encode()
        );

        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        assertLe(
            ark.pendingWithdrawalShares(),
            balance,
            "pendingWithdrawalShares exceeded available share balance - L9 cap broken"
        );
    }
}
