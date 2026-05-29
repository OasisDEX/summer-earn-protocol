// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

import {SuperstateSubscribeArk} from "../../../src/contracts/arks/SuperstateSubscribeArk.sol";
import {MockShareTokenWithBurn, MockSuperstateSubscribeWithMint, MockRedeemContract, MockOracleWithDrift} from "./SuperstateInvariantsCommon.sol";

/// @notice Action handler for the SuperstateSubscribeArk invariant suite.
contract SuperstateSubscribeArkHandler is Test {
    using SafeERC20 for IERC20;

    SuperstateSubscribeArk public immutable ark;
    MockShareTokenWithBurn public immutable shareToken;
    MockSuperstateSubscribeWithMint public immutable subscribeContract;
    MockRedeemContract public immutable redeemContract;
    MockOracleWithDrift public immutable oracle;
    IERC20 public immutable usdc;

    address public immutable keeper;
    address public immutable governor;
    address public immutable commander;
    address public immutable bufferArk;

    uint256 public constant MAX_AMOUNT = 1_000_000 * 1e6;

    /* ----- ghost state ----- */

    uint256 public sharesBalanceBeforeRequest;
    bool public lastRequestSucceeded;
    bool public lastSweepSucceeded;

    constructor(
        SuperstateSubscribeArk _ark,
        MockShareTokenWithBurn _shareToken,
        MockSuperstateSubscribeWithMint _subscribeContract,
        MockRedeemContract _redeemContract,
        MockOracleWithDrift _oracle,
        address _usdc,
        address _keeper,
        address _governor,
        address _commander,
        address _bufferArk
    ) {
        ark = _ark;
        shareToken = _shareToken;
        subscribeContract = _subscribeContract;
        redeemContract = _redeemContract;
        oracle = _oracle;
        usdc = IERC20(_usdc);
        keeper = _keeper;
        governor = _governor;
        commander = _commander;
        bufferArk = _bufferArk;
    }

    /* ============================================================
                              ACTIONS
    ============================================================ */

    /// @notice Commander boards `amount` USDC; the subscribe mock synchronously mints shares to the
    ///         ark at its configured ratio.
    function board(uint256 amount) external {
        amount = bound(amount, 0, MAX_AMOUNT);
        deal(address(usdc), commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        try ark.board(amount, bytes("")) {} catch {}
        vm.stopPrank();
    }

    /// @notice Commander disembarks `amount` USDC through the synchronous redeem path. The redeem
    ///         contract needs to be funded with USDC beforehand — we ensure that here.
    function disembark(uint256 amount) external {
        amount = bound(amount, 0, MAX_AMOUNT);
        // Ensure the redeem contract has enough USDC to pay out the worst-case redemption.
        // `redeem(shares, to)` pays `shares * usdcPerShare` USDC; for our mock, usdcPerShare = 10.
        deal(address(usdc), address(redeemContract), MAX_AMOUNT * 10);
        vm.prank(commander);
        try ark.disembark(amount, bytes("")) {} catch {}
    }

    function requestWithdrawal(uint256 amount) external {
        amount = bound(amount, 0, MAX_AMOUNT);
        sharesBalanceBeforeRequest = shareToken.balanceOf(address(ark));
        lastRequestSucceeded = false;
        vm.prank(keeper);
        try ark.requestWithdrawal(amount) {
            lastRequestSucceeded = true;
            // I12 (L9 cap postcondition)
            assertLe(
                ark.pendingWithdrawalShares(),
                sharesBalanceBeforeRequest,
                "L9 cap broken: pending exceeded share balance at request time"
            );
        } catch {}
    }

    function simulateSettlement(uint256 amount) external {
        amount = bound(amount, 0, MAX_AMOUNT);
        deal(address(usdc), address(ark), amount);
    }

    function sweep() external {
        lastSweepSucceeded = false;
        vm.prank(keeper);
        try ark.sweep() {
            lastSweepSucceeded = true;
            assertEq(
                ark.pendingWithdrawalShares(),
                0,
                "I11: pendingWithdrawalShares non-zero after successful sweep"
            );
        } catch {}
    }

    function emergencySweep() external {
        lastSweepSucceeded = false;
        vm.prank(governor);
        try ark.emergencySweep() {
            lastSweepSucceeded = true;
            assertEq(
                ark.pendingWithdrawalShares(),
                0,
                "I11: pendingWithdrawalShares non-zero after successful emergencySweep"
            );
        } catch {}
    }

    function setSweepSlippage(uint256 raw) external {
        Percentage maxP = ark.MAX_SWEEP_SLIPPAGE();
        Percentage p = Percentage.wrap(
            bound(raw, 0, Percentage.unwrap(maxP) * 2)
        );
        vm.prank(keeper);
        try ark.setSweepSlippage(p) {
            assertEq(
                Percentage.unwrap(ark.sweepSlippage()),
                Percentage.unwrap(p),
                "sweepSlippage state didn't match set value"
            );
        } catch {}
    }

    function setDepositSlippage(uint256 raw) external {
        Percentage maxP = ark.MAX_DEPOSIT_SLIPPAGE();
        Percentage p = Percentage.wrap(
            bound(raw, 0, Percentage.unwrap(maxP) * 2)
        );
        vm.prank(keeper);
        try ark.setDepositSlippage(p) {
            assertEq(
                Percentage.unwrap(ark.depositSlippage()),
                Percentage.unwrap(p),
                "depositSlippage state didn't match set value"
            );
        } catch {}
    }

    function setSubscribeMintRatio(uint256 num, uint256 den) external {
        den = bound(den, 1, 1_000_000);
        num = bound(num, 0, den * 2);
        subscribeContract.setMintRatio(num, den);
    }

    function touchOracle() external {
        oracle.touch();
    }

    function driftOracle(uint256 raw) external {
        int256 newAnswer = int256(bound(raw, 1e8, 100 * 1e8));
        oracle.setAnswer(newAnswer);
    }
}
