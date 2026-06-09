// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

import {SuperstateStandardArk} from "../../../src/contracts/arks/SuperstateStandardArk.sol";
import {MockShareTokenWithBurn, MockOracleWithDrift} from "./SuperstateInvariantsCommon.sol";

/// @notice Action handler for the SuperstateStandardArk invariant suite. Every external entry
///         point on the ark gets a bounded wrapper; the invariant runner calls these wrappers at
///         random with random arguments. Successful actions snapshot ghost state used by
///         post-condition invariants.
contract SuperstateStandardArkHandler is Test {
    using SafeERC20 for IERC20;

    SuperstateStandardArk public immutable ark;
    MockShareTokenWithBurn public immutable shareToken;
    MockOracleWithDrift public immutable oracle;
    IERC20 public immutable usdc;
    address public immutable depositAddress;

    address public immutable keeper;
    address public immutable governor;
    address public immutable commander;
    address public immutable bufferArk;

    uint256 public constant MAX_AMOUNT = 1_000_000 * 1e6; // 1M USDC
    uint256 public constant MAX_SHARES = 1_000_000 * 1e6; // 1M shares (6 decimals)

    /* ----- ghost state ----- */

    /// @notice Last share balance observed just before a `requestWithdrawal`. Used by the L9 cap
    ///         postcondition invariant (`pendingWithdrawalShares <= sharesBalanceBeforeRequest`).
    uint256 public sharesBalanceBeforeRequest;
    bool public lastRequestSucceeded;

    /// @notice `pendingWithdrawalShares` before the most recent sweep / emergency sweep. Used by
    ///         the post-sweep invariant (after a successful sweep, pending must be 0).
    bool public lastSweepSucceeded;

    /// @notice Snapshot of `totalAssets()` after the last `setArkFrozen(true, …)` call. Used by
    ///         the frozen-lock invariant; reset on each (re)freeze.
    uint256 public frozenTotalsSnapshot;
    bool public hasFrozenSnapshot;

    /// @notice Shares added to `pendingWithdrawalShares` since the last (emergency)sweep. Used by
    ///         I15 (withdrawal cycle consistency: `pendingWithdrawalShares == this`).
    uint256 public ghost_sharesAddedToPendingWithdrawal;

    /// @notice Outstanding pending-deposit volume since last (emergency)clear. Used by I16
    ///         (deposit cycle consistency: `pendingDepositAssets == this`).
    uint256 public ghost_pendingDepositCycle;

    constructor(
        SuperstateStandardArk _ark,
        MockShareTokenWithBurn _shareToken,
        MockOracleWithDrift _oracle,
        address _usdc,
        address _depositAddress,
        address _keeper,
        address _governor,
        address _commander,
        address _bufferArk
    ) {
        ark = _ark;
        shareToken = _shareToken;
        oracle = _oracle;
        usdc = IERC20(_usdc);
        depositAddress = _depositAddress;
        keeper = _keeper;
        governor = _governor;
        commander = _commander;
        bufferArk = _bufferArk;
    }

    /* ============================================================
                              ACTIONS
    ============================================================ */

    /// @notice Commander boards `amount` USDC. Funds the commander beforehand via cheatcodes.
    function board(uint256 amount) external {
        amount = bound(amount, 0, MAX_AMOUNT);
        deal(address(usdc), commander, amount);
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        try ark.board(amount, bytes("")) {
            ghost_pendingDepositCycle += amount;
        } catch {}
        vm.stopPrank();
    }

    /// @notice Simulates Superstate minting shares for an in-flight pending deposit.
    function simulateShareMint(uint256 amount) external {
        amount = bound(amount, 0, MAX_SHARES);
        shareToken.mint(address(ark), amount);
    }

    /// @notice Simulates Superstate sending settlement USDC back to the ark for an outstanding redemption.
    function simulateSettlement(uint256 amount) external {
        amount = bound(amount, 0, MAX_AMOUNT);
        deal(address(usdc), address(ark), amount);
    }

    function clearPendingDeposit() external {
        vm.prank(keeper);
        try ark.clearPendingDeposit() {
            ghost_pendingDepositCycle = 0; // full clear
        } catch {}
    }

    function requestWithdrawal(uint256 amount) external {
        amount = bound(amount, 0, MAX_AMOUNT);
        sharesBalanceBeforeRequest = shareToken.balanceOf(address(ark));
        lastRequestSucceeded = false;
        uint256 pendingBefore = ark.pendingWithdrawalShares();
        vm.prank(keeper);
        try ark.requestWithdrawal(amount) {
            lastRequestSucceeded = true;
            uint256 pendingAfter = ark.pendingWithdrawalShares();
            ghost_sharesAddedToPendingWithdrawal += (pendingAfter -
                pendingBefore);
            // I12 (L9 cap postcondition): pendingWithdrawalShares <= balance-at-call-time.
            // Since the base reverts on `pendingWithdrawalShares > 0`, pre-call pending must have
            // been 0, so post-call pending equals the newly-added (capped) tranche.
            assertLe(
                pendingAfter,
                sharesBalanceBeforeRequest,
                "L9 cap broken: pendingWithdrawalShares exceeded share balance at request time"
            );
        } catch {}
    }

    function sweep() external {
        lastSweepSucceeded = false;
        vm.prank(keeper);
        try ark.sweep() {
            lastSweepSucceeded = true;
            ghost_sharesAddedToPendingWithdrawal = 0; // cycle reset
            // I11: after a successful sweep, pendingWithdrawalShares must be zeroed.
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
            ghost_sharesAddedToPendingWithdrawal = 0;
            // Same I11 invariant — emergencySweep also zeroes the counter.
            assertEq(
                ark.pendingWithdrawalShares(),
                0,
                "I11: pendingWithdrawalShares non-zero after successful emergencySweep"
            );
        } catch {}
    }

    function emergencyClearPendingDeposit(uint256 amount) external {
        amount = bound(amount, 0, ark.pendingDepositAssets() + 1);
        vm.prank(governor);
        try ark.emergencyClearPendingDeposit(amount) {
            // Partial emergency clear: decrement the cycle by the cleared amount.
            ghost_pendingDepositCycle -= amount;
        } catch {}
    }

    function setArkFrozen(bool isFrozen, uint256 frozenValue) external {
        if (isFrozen) {
            uint256 toUse;
            if (frozenValue % 4 == 0) {
                toUse = type(uint256).max; // sentinel branch — snapshot live totalAssets
            } else {
                toUse = bound(frozenValue, 0, type(uint128).max);
            }
            vm.prank(keeper);
            try ark.setArkFrozen(true, toUse) {
                frozenTotalsSnapshot = ark.totalAssets();
                hasFrozenSnapshot = true;
            } catch {}
        } else {
            vm.prank(keeper);
            try ark.setArkFrozen(false, 0) {
                hasFrozenSnapshot = false;
            } catch {}
        }
    }

    function setSweepSlippage(uint256 raw) external {
        Percentage maxP = ark.MAX_SWEEP_SLIPPAGE();
        Percentage p = Percentage.wrap(
            bound(raw, 0, Percentage.unwrap(maxP) * 2)
        );
        vm.prank(keeper);
        try ark.setSweepSlippage(p) {
            // Postcondition: stored slippage matches the supplied value
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

    /// @notice Refreshes the oracle's `updatedAt` so subsequent reads don't trip the staleness
    ///         revert after `vm.warp` (the invariant runner can advance time arbitrarily).
    function touchOracle() external {
        oracle.touch();
    }

    /// @notice Drifts the oracle price within a sane band so the conversion math is exercised.
    function driftOracle(uint256 raw) external {
        int256 newAnswer = int256(bound(raw, 1e8, 100 * 1e8)); // $0.01 to $100 per share
        oracle.setAnswer(newAnswer);
    }
}
