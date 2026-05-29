// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SuperstateSubscribeArk.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {AggregatorV3Interface} from "../../src/interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {ISuperstateToken, SupportedStablecoin} from "../../src/interfaces/superstate/ISuperstateToken.sol";
import {ISuperstateRedeem} from "../../src/interfaces/superstate/ISuperstateRedeem.sol";
import "../../src/events/IArkEvents.sol";
import {ISuperstateArkErrors} from "../../src/errors/arks/ISuperstateArkErrors.sol";
import {ISuperstateSubscribeArkErrors} from "../../src/errors/arks/ISuperstateSubscribeArkErrors.sol";
import {ISuperstateSubscribeArk} from "../../src/interfaces/arks/ISuperstateSubscribeArk.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
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
        uint80 roundId_,
        int256 answer_,
        uint256 updatedAt_,
        uint80 answeredInRound_
    ) external {
        _roundId = roundId_;
        _answer = answer_;
        _updatedAt = updatedAt_;
        _answeredInRound = answeredInRound_;
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

contract MockSuperstateSubscribe is ISuperstateToken {
    using SafeERC20 for IERC20;
    IERC20 public usdc;
    address public _superstateOracle;

    /// @notice Share token to mint into during `subscribe`. Tests set this in setUp.
    MockERC20 public mintTarget;
    /// @notice Numerator of the shares-per-USDC ratio (default: 1).
    uint256 public mintNum = 1;
    /// @notice Denominator of the shares-per-USDC ratio (default: 10 — matches the 10:1 oracle mock).
    uint256 public mintDen = 10;

    constructor(address _usdc, address oracle_) {
        usdc = IERC20(_usdc);
        _superstateOracle = oracle_;
    }

    function setMintTarget(address _shareToken) external {
        mintTarget = MockERC20(_shareToken);
    }

    /// @notice Configures the shares-per-USDC ratio. Set to `0,1` to simulate underpayment.
    function setMintRatio(uint256 num, uint256 den) external {
        mintNum = num;
        mintDen = den;
    }

    function subscribe(
        address to,
        uint256 inAmount,
        address stablecoin
    ) external override {
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            inAmount
        );
        if (address(mintTarget) != address(0) && mintDen > 0) {
            mintTarget.mint(to, (inAmount * mintNum) / mintDen);
        }
    }

    function subscribe(uint256 inAmount, address stablecoin) external override {
        IERC20(stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            inAmount
        );
        if (address(mintTarget) != address(0) && mintDen > 0) {
            mintTarget.mint(msg.sender, (inAmount * mintNum) / mintDen);
        }
    }

    function supportedStablecoins(
        address /*stablecoin*/
    ) external pure override returns (SupportedStablecoin memory) {
        return SupportedStablecoin({sweepDestination: address(0x5555), fee: 0});
    }

    function superstateOracle() external view override returns (address) {
        return _superstateOracle;
    }

    function offchainRedeem(uint256) external override {}
}

contract MockSuperstateRedeem is ISuperstateRedeem {
    using SafeERC20 for IERC20;
    IERC20 public shareToken;
    IERC20 public usdc;

    constructor(address _shareToken, address _usdc) {
        shareToken = IERC20(_shareToken);
        usdc = IERC20(_usdc);
    }

    function redeem(uint256 amount, address to) external {
        shareToken.safeTransferFrom(msg.sender, address(this), amount);
        usdc.safeTransfer(to, amount * 10);
    }
}

contract MockSuperstateToken is MockERC20, ISuperstateToken {
    address public expectedStablecoin;
    address public configuredSweepDestination;

    function setSupportedStablecoin(
        address stablecoin,
        address sweepDestination
    ) external {
        expectedStablecoin = stablecoin;
        configuredSweepDestination = sweepDestination;
    }

    function supportedStablecoins(
        address stablecoin
    ) external view override returns (SupportedStablecoin memory) {
        if (stablecoin == expectedStablecoin) {
            return
                SupportedStablecoin({
                    sweepDestination: configuredSweepDestination,
                    fee: 0
                });
        }
        return SupportedStablecoin({sweepDestination: address(0), fee: 0});
    }

    function subscribe(address, uint256, address) external override {}

    function subscribe(uint256, address) external override {}

    function superstateOracle() external pure override returns (address) {
        return address(0);
    }

    function offchainRedeem(uint256) external override {}
}

contract SuperstateSubscribeArkTest is Test, IArkEvents, ArkTestBaseWhitelist {
    using SafeERC20 for IERC20;

    SuperstateSubscribeArk public ark;
    IERC20 public usdc;
    MockSuperstateToken public shareToken;
    MockSuperstateOracle public oracle;
    MockSuperstateSubscribe public subscribeContract;
    MockSuperstateRedeem public redeemContract;

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

        shareToken = new MockSuperstateToken();
        shareToken.initialize("USTB", "USTB", 6);
        shareToken.setSupportedStablecoin(USDC_ADDRESS, address(0x5555));

        oracle = new MockSuperstateOracle(8, 10 * 1e8); // 1 share = 10 USDC

        subscribeContract = new MockSuperstateSubscribe(
            USDC_ADDRESS,
            address(oracle)
        );
        // Wire the mock to mint MockSuperstateToken shares during subscribe (1 share per 10 USDC,
        // matching the oracle mock's 10:1 price).
        subscribeContract.setMintTarget(address(shareToken));

        redeemContract = new MockSuperstateRedeem(
            address(shareToken),
            USDC_ADDRESS
        );

        params = ArkParams({
            name: "USDC Superstate Subscribe Ark",
            details: "USDC Superstate Subscribe Ark details",
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
        ark = new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            sweepSlippage,
            depositSlippage,
            params
        );
        vm.stopPrank();

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
        Percentage sweepSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);
        Percentage depositSlippage = Percentage.wrap(PERCENTAGE_FACTOR / 2);

        vm.expectRevert(ISuperstateArkErrors.InvalidShareTokenAddress.selector);
        new SuperstateSubscribeArk(
            address(0),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            sweepSlippage,
            depositSlippage,
            params
        );

        vm.expectRevert(
            ISuperstateSubscribeArkErrors.InvalidSubscribeAddress.selector
        );
        new SuperstateSubscribeArk(
            address(shareToken),
            address(0),
            address(redeemContract),
            address(oracle),
            sweepSlippage,
            depositSlippage,
            params
        );

        vm.expectRevert(ISuperstateArkErrors.InvalidOracleAddress.selector);
        new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(0),
            sweepSlippage,
            depositSlippage,
            params
        );

        assertEq(address(ark.asset()), USDC_ADDRESS, "Asset should match");
    }

    function test_UnsupportedStablecoin() public {
        vm.startPrank(governor);

        vm.mockCall(
            address(subscribeContract),
            abi.encodeWithSelector(
                ISuperstateToken.supportedStablecoins.selector,
                USDC_ADDRESS
            ),
            abi.encode(address(0), uint96(0))
        );

        vm.expectRevert(
            ISuperstateSubscribeArkErrors.UnsupportedStablecoin.selector
        );
        new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
        vm.stopPrank();
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 initialTargetBalance = usdc.balanceOf(
            address(subscribeContract)
        );

        // MockSuperstateSubscribe mints 1 share per 10 USDC during subscribe(),
        // matching the oracle's 10:1 price so the inherited deposit-slippage check passes.
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalTargetBalance = usdc.balanceOf(address(subscribeContract));
        assertEq(
            finalTargetBalance,
            initialTargetBalance + amount,
            "Subscribe contract should receive tokens"
        );

        assertEq(
            shareToken.balanceOf(address(ark)),
            (amount) / 10,
            "Ark should hold the minted shares"
        );
        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets should match boarded amount"
        );
    }

    function test_Board_RevertsWhenSharesUnderpaid() public {
        // Simulate Superstate enabling a 5% fee (or otherwise minting fewer shares than expected).
        // 5% under the 1:10 ratio is well outside the 0.5% deposit slippage band.
        subscribeContract.setMintRatio(95, 1000); // 9.5 shares per 100 USDC instead of 10

        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISuperstateArkErrors.SharesNotArrived.selector,
                uint256(100 * 1e6), // expected: 100 shares for 1000 USDC at 10:1
                uint256(95 * 1e6) // actual: 95 shares (5% short)
            )
        );
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_Board_WithinDepositSlippage() public {
        // Simulate Superstate minting just under the 0.5% deposit slippage band — should pass.
        // 99.6 shares for 100 expected = 0.4% short, inside the 0.5% tolerance.
        subscribeContract.setMintRatio(996, 10000);

        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        assertEq(
            shareToken.balanceOf(address(ark)),
            (amount * 996) / 10000,
            "Ark should hold the partially-minted shares"
        );
    }

    function test_Disembark() public {
        // Setup initial shares
        uint256 amount = 1000 * 1e6;
        uint256 shares = 100 * 1e6;
        shareToken.mint(address(ark), shares);

        // Need to give the redeem contract USDC to pay out
        deal(USDC_ADDRESS, address(redeemContract), amount);

        vm.startPrank(commander);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();

        assertEq(
            shareToken.balanceOf(address(redeemContract)),
            shares,
            "Redeem contract should receive shares"
        );
    }

    function test_Disembark_PartialExit() public {
        // Mint 100 shares (= 1000 USDC at oracle price of 10).
        uint256 shares = 100 * 1e6;
        shareToken.mint(address(ark), shares);

        // Provide the redeem contract with enough USDC.
        deal(USDC_ADDRESS, address(redeemContract), 1000 * 1e6);

        // Disembark only half — exercises the partial branch (uses _assetsToShares).
        uint256 partialAmount = 500 * 1e6;
        uint256 expectedSharesRedeemed = 50 * 1e6;

        vm.startPrank(commander);
        ark.disembark(partialAmount, bytes(""));
        vm.stopPrank();

        assertEq(
            shareToken.balanceOf(address(redeemContract)),
            expectedSharesRedeemed,
            "Redeem contract should receive only the partial shares"
        );
        assertEq(
            shareToken.balanceOf(address(ark)),
            shares - expectedSharesRedeemed,
            "Remaining shares stay on the ark"
        );
    }

    function test_Disembark_RevertsWithDirectWithdrawalNotAvailable_WhenSyncFails()
        public
    {
        // Mint shares onto the ark.
        uint256 shares = 100 * 1e6;
        shareToken.mint(address(ark), shares);

        // Sync path will revert: don't fund the redeem contract with USDC. MockSuperstateRedeem.redeem
        // pulls shares from ark then tries to safeTransfer USDC it does not have, which reverts inside
        // the try block. The catch branch in `_disembark` then reverts with `DirectWithdrawalNotAvailable`,
        // unwinding the share transfer.
        vm.startPrank(commander);
        vm.expectRevert(
            ISuperstateSubscribeArkErrors.DirectWithdrawalNotAvailable.selector
        );
        ark.disembark(500 * 1e6, bytes(""));
        vm.stopPrank();

        // State is fully unwound by the revert.
        assertEq(
            ark.pendingWithdrawalShares(),
            0,
            "pendingWithdrawalShares stays 0 after the tx unwinds"
        );
        assertEq(
            shareToken.balanceOf(address(ark)),
            shares,
            "Shares remain on the ark"
        );
    }

    /* Stacked-Withdrawal Guard (Pashov audit #3 fix ported from WisdomTreeArk) */

    function test_RequestWithdrawal_RevertsIfPendingWithdrawal() public {
        // Mint enough shares for two requestWithdrawal calls
        uint256 amount = 1000 * 1e6;
        shareToken.mint(address(ark), 200 * 1e6);

        vm.startPrank(keeper);

        // First withdrawal queues fine
        ark.requestWithdrawal(amount);

        // Second withdrawal must revert because a cycle is in flight
        vm.expectRevert(ISuperstateArkErrors.PendingWithdrawalActive.selector);
        ark.requestWithdrawal(amount);
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
        // sweepSlippage defaults to 0 for SubscribeArk (constructor doesn't set it),
        // so any USDC-vs-shares mismatch makes the keeper sweep revert.

        // Prime an active redemption cycle
        uint256 amount = 1000 * 1e6;
        shareToken.mint(address(ark), 100 * 1e6);

        vm.startPrank(keeper);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        // Simulate Superstate returning less than expected
        uint256 returnedUsdc = 900 * 1e6;
        deal(USDC_ADDRESS, address(ark), returnedUsdc);

        // Deploy and wire up a buffer ark for the sweep destination
        ArkParams memory bParams = ArkParams({
            name: "BufferArk",
            details: "BufferArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        BufferArk bufferArk = new BufferArk(bParams, address(commander));

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

        // Keeper sweep would revert (returned shares < pendingWithdrawalShares with 0 slippage)
        vm.startPrank(keeper);
        vm.expectRevert();
        ark.sweep();
        vm.stopPrank();

        // Governor emergencySweep skips the slippage check
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
            "Buffer ark received the swept asset"
        );
    }

    /* L9 cap regression (inherited base behavior) */

    function test_RequestWithdrawal_CapsAtShareBalance() public {
        // Only 1 share available; request asks for 100 shares worth
        uint256 sharesAvailable = 1e6;
        shareToken.mint(address(ark), sharesAvailable);

        uint256 amount = 1000 * 1e6;
        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        assertEq(
            ark.pendingWithdrawalShares(),
            sharesAvailable,
            "pendingWithdrawalShares must be capped at share balance"
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
        oracle.setRoundData(1, 10 * 1e8, block.timestamp - 24 hours - 1, 1);
        vm.prank(keeper);
        vm.expectRevert(ISuperstateArkErrors.StaleOraclePrice.selector);
        ark.requestWithdrawal(1e6);
    }

    function test_Board_RevertsIfOracleStale() public {
        // Subscribe's _board calls _validateReceivedShares which reads the oracle
        oracle.setRoundData(1, 10 * 1e8, block.timestamp - 24 hours - 1, 1);
        uint256 amount = 100 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        vm.expectRevert(ISuperstateArkErrors.StaleOraclePrice.selector);
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_TotalAssets_RevertsIfOracleStale_WhenSharesPresent() public {
        shareToken.mint(address(ark), 1e6);
        oracle.setRoundData(1, 10 * 1e8, block.timestamp - 24 hours - 1, 1);
        vm.expectRevert(ISuperstateArkErrors.StaleOraclePrice.selector);
        ark.totalAssets();
    }

    function test_TotalAssets_DoesNotTouchOracleWhenEmpty() public view {
        assertEq(ark.totalAssets(), 0);
    }

    /* Slippage cap setters + constructor validation */

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

    function test_Constructor_RevertsIfSweepSlippageAboveMax() public {
        Percentage above = Percentage.wrap(PERCENTAGE_FACTOR / 2 + 1);
        vm.expectRevert();
        new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            above,
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            params
        );
    }

    function test_Constructor_RevertsIfDepositSlippageAboveMax() public {
        Percentage above = Percentage.wrap(PERCENTAGE_FACTOR / 2 + 1);
        vm.expectRevert();
        new SuperstateSubscribeArk(
            address(shareToken),
            address(subscribeContract),
            address(redeemContract),
            address(oracle),
            Percentage.wrap(PERCENTAGE_FACTOR / 2),
            above,
            params
        );
    }

    /* Disembark branch coverage */

    function test_Disembark_FullExitBranch_DrainsAllShares() public {
        uint256 amount = 100 * 1e6;
        uint256 shares = 10 * 1e6; // 10 shares * 10 USDC/share = 100 USDC

        shareToken.mint(address(ark), shares);
        deal(USDC_ADDRESS, address(redeemContract), amount);

        vm.prank(commander);
        ark.disembark(amount, bytes(""));

        // Full-exit branch redeems entire share balance, leaving 0 in the ark
        assertEq(
            shareToken.balanceOf(address(ark)),
            0,
            "Full-exit must drain shares"
        );
        assertEq(
            shareToken.balanceOf(address(redeemContract)),
            shares,
            "Redeem contract holds the burned shares"
        );
    }

    function test_Disembark_RevertsWhenNoSharesToRedeem() public {
        // No shares minted to the ark
        vm.prank(commander);
        vm.expectRevert();
        ark.disembark(100 * 1e6, bytes(""));
    }

    /* Fuzz */

    function testFuzz_SharesAssetsRoundTrip(uint256 amount) public {
        amount = bound(amount, 10, 1_000_000 * 1e6);
        shareToken.mint(address(ark), 1_000_000 * 1e6);

        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        uint256 roundTrip = ark.assetsInWithdrawalQueue();
        assertLe(roundTrip, amount, "round-trip cannot increase the value");
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

    function testFuzz_RequestWithdrawal_CapsAtShareBalance(
        uint256 balance,
        uint256 amount
    ) public {
        balance = bound(balance, 1, 1_000_000 * 1e6);
        amount = bound(amount, 1, 1_000_000_000 * 1e6);

        shareToken.mint(address(ark), balance);

        vm.prank(keeper);
        ark.requestWithdrawal(amount);

        assertLe(
            ark.pendingWithdrawalShares(),
            balance,
            "pendingWithdrawalShares exceeded available share balance - L9 cap broken"
        );
    }

    function testFuzz_Board_DepositSlippageBoundary(
        uint256 num,
        uint256 den
    ) public {
        den = bound(den, 1, 1_000_000);
        num = bound(num, 0, den * 2);
        subscribeContract.setMintRatio(num, den);

        uint256 amount = 1000 * 1e6;
        deal(USDC_ADDRESS, commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        // 1 share = 10 USDC at the mock oracle price, so expectedShares = amount / 10
        uint256 expectedShares = amount / 10;
        uint256 actualShares = (amount * num) / den;
        // depositSlippage = 0.5% => band = expectedShares * 199 / 200
        uint256 minAcceptedShares = (expectedShares * 199) / 200;

        if (actualShares >= minAcceptedShares) {
            ark.board(amount, bytes(""));
            assertEq(
                shareToken.balanceOf(address(ark)),
                actualShares,
                "Ark holds the actually-minted shares"
            );
        } else {
            vm.expectRevert();
            ark.board(amount, bytes(""));
        }
        vm.stopPrank();
    }
}
