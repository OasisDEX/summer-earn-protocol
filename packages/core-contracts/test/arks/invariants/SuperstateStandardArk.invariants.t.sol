// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

import {SuperstateStandardArk} from "../../../src/contracts/arks/SuperstateStandardArk.sol";
import {BufferArk} from "../../../src/contracts/arks/BufferArk.sol";
import {ArkParams} from "../../../src/types/ArkTypes.sol";

import {ArkTestBaseWhitelist} from "../ArkTestBaseWhitelist.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockShareTokenWithBurn, MockOracleWithDrift} from "./SuperstateInvariantsCommon.sol";
import {SuperstateStandardArkHandler} from "./SuperstateStandardArkHandler.sol";

/// @notice Invariant suite for SuperstateStandardArk. The handler drives a randomized sequence of
///         board / clear / request / sweep / freeze / emergency / slippage-set / oracle-drift
///         actions; this contract asserts the invariants documented in the audit analysis.
contract SuperstateStandardArkInvariants is Test, ArkTestBaseWhitelist {
    SuperstateStandardArk public ark;
    SuperstateStandardArkHandler public handler;
    BufferArk public bufferArk;

    MockERC20 public usdc;
    MockShareTokenWithBurn public shareToken;
    MockOracleWithDrift public oracle;
    address public depositAddress = address(0x1111);

    function setUp() public {
        initializeCoreContracts();

        usdc = new MockERC20();
        usdc.initialize("USDC", "USDC", 6);

        shareToken = new MockShareTokenWithBurn();
        shareToken.initialize("USTB", "USTB", 6);

        oracle = new MockOracleWithDrift(8, 10 * 1e8); // 1 share = 10 USDC

        ArkParams memory params = ArkParams({
            name: "Standard Ark",
            details: "details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

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

        // Buffer ark for sweep destination
        ArkParams memory bParams = ArkParams({
            name: "BufferArk",
            details: "buffer details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        bufferArk = new BufferArk(bParams, address(commander));

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), commander);
        accessManager.grantKeeperRole(address(ark), keeper);
        vm.stopPrank();

        vm.prank(commander);
        ark.registerFleetCommander();

        // Persistent commander mocks so the ark can resolve bufferArk during sweep
        vm.mockCall(
            commander,
            abi.encodeWithSignature("bufferArk()"),
            abi.encode(address(bufferArk))
        );
        vm.mockCall(
            commander,
            abi.encodeWithSignature("isArkActiveOrBufferArk(address)"),
            abi.encode(true)
        );

        handler = new SuperstateStandardArkHandler(
            ark,
            shareToken,
            oracle,
            address(usdc),
            depositAddress,
            keeper,
            governor,
            commander,
            address(bufferArk)
        );

        // Restrict the invariant runner to handler actions
        targetContract(address(handler));
    }

    /* ============================================================
                              INVARIANTS
    ============================================================ */

    /// @notice I1: `sweepSlippage` never exceeds its cap.
    function invariant_SweepSlippageBounded() public view {
        assertLe(
            Percentage.unwrap(ark.sweepSlippage()),
            Percentage.unwrap(ark.MAX_SWEEP_SLIPPAGE()),
            "I1: sweepSlippage > MAX_SWEEP_SLIPPAGE"
        );
    }

    /// @notice I2: `depositSlippage` never exceeds its cap.
    function invariant_DepositSlippageBounded() public view {
        assertLe(
            Percentage.unwrap(ark.depositSlippage()),
            Percentage.unwrap(ark.MAX_DEPOSIT_SLIPPAGE()),
            "I2: depositSlippage > MAX_DEPOSIT_SLIPPAGE"
        );
    }

    /// @notice I4/I5: totalAssets() reconstructs from on-chain composition while not frozen.
    function invariant_TotalAssetsIdentity_NotFrozen() public view {
        if (ark.isArkFrozen()) return;

        uint256 actual = ark.totalAssets();
        uint256 pending = ark.pendingWithdrawalShares();
        uint256 pendingDeposit = ark.pendingDepositAssets();

        uint256 shares = pendingDeposit > 0
            ? ark.cachedShareBalance()
            : shareToken.balanceOf(address(ark));

        uint256 expected = ark.sharesToAssets(shares + pending) +
            pendingDeposit;

        assertEq(
            actual,
            expected,
            "I4/I5: totalAssets identity broken when not frozen"
        );
    }

    /// @notice I10: while frozen, totalAssets() equals the snapshot taken at freeze time and does
    ///         not move with the oracle.
    function invariant_FrozenLock() public view {
        if (!ark.isArkFrozen()) return;
        if (!handler.hasFrozenSnapshot()) return;

        assertEq(
            ark.totalAssets(),
            handler.frozenTotalsSnapshot(),
            "I10: frozen totalAssets shifted between calls"
        );
    }

    /// @notice I8 identity: assetsInWithdrawalQueue == sharesToAssets(pendingWithdrawalShares).
    function invariant_AssetsInWithdrawalQueueIdentity() public view {
        uint256 pending = ark.pendingWithdrawalShares();
        assertEq(
            ark.assetsInWithdrawalQueue(),
            ark.sharesToAssets(pending),
            "I8: assetsInWithdrawalQueue identity broken"
        );
    }

    /// @notice I14: share conservation — every share minted to the ark is either still held by
    ///         the ark or has been burned via `offchainRedeem`. Standard ark never transfers
    ///         shares out to a third-party contract, so there is no third term.
    function invariant_ShareConservation() public view {
        uint256 minted = shareToken.totalMintedTo(address(ark));
        uint256 burned = shareToken.totalBurnedFrom(address(ark));
        uint256 held = shareToken.balanceOf(address(ark));
        assertEq(
            minted,
            held + burned,
            "I14: share conservation broken (mints != held + burned)"
        );
    }

    /// @notice I15: `pendingWithdrawalShares` equals the cumulative shares queued since the last
    ///         (emergency)sweep. Since the base contract enforces single-tranche withdrawals,
    ///         the ghost should always equal the live counter.
    function invariant_WithdrawalCycleConsistency() public view {
        assertEq(
            ark.pendingWithdrawalShares(),
            handler.ghost_sharesAddedToPendingWithdrawal(),
            "I15: pendingWithdrawalShares != cumulative queued since last sweep"
        );
    }

    /// @notice I16: `pendingDepositAssets` equals the cumulative boarded amount minus what has
    ///         been cleared (full keeper clear or partial governor clear) since cycle start.
    function invariant_DepositCycleConsistency() public view {
        assertEq(
            ark.pendingDepositAssets(),
            handler.ghost_pendingDepositCycle(),
            "I16: pendingDepositAssets != cumulative boarded - cleared this cycle"
        );
    }

    /// @notice Diagnostic: prints how many times each handler action ran. Off by default; flip on
    ///         when debugging coverage. (Foundry runs view-or-pure invariant_* functions even when
    ///         they call console.log.)
    function invariant_callSummary() public view {
        // Intentionally empty — placeholder for adding selector counters if coverage looks off.
    }
}
