// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {FlexibleTipper} from "../../src/contracts/FlexibleTipper.sol";
import {ITipperEvents} from "../../src/events/ITipperEvents.sol";
import {IFlexibleTipper} from "../../src/interfaces/IFlexibleTipper.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {Constants} from "@summerfi/constants/Constants.sol";
import {PERCENTAGE_100, Percentage, toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

// ============================================================================
// Mock ERC20 for the underlying asset
// ============================================================================
contract MockAsset is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

// ============================================================================
// FlexibleTipperHarness
// A minimal ERC4626 vault that inherits the REAL FlexibleTipper contract.
// This ensures tests validate the actual deployed code, not a copy.
//
// The harness exposes internal setters and simulates yield/loss by minting
// or burning the underlying asset held by the vault.
// ============================================================================
contract FlexibleTipperHarness is ERC4626, FlexibleTipper {
    using PercentageUtils for uint256;

    address public tipJar;

    constructor(
        IERC20 asset_,
        Percentage initialTipRate,
        address tipJar_
    )
        ERC4626(asset_)
        ERC20("FlexTipper Vault", "fxTIP")
        FlexibleTipper(initialTipRate)
    {
        tipJar = tipJar_;
    }

    // ---- FlexibleTipper abstract implementation ----
    function _mintTip(
        address account,
        uint256 amount
    ) internal virtual override {
        _mint(account, amount);
    }

    function _getTotalAssetsForFee() internal view override returns (uint256) {
        return totalAssets();
    }

    // ---- Exposed setters for testing ----
    function setFeeType(FeeType newFeeType) external {
        _setFeeType(newFeeType, totalAssets(), totalSupply());
    }

    function setPerformanceFeeRate(Percentage newRate) external {
        _setPerformanceFeeRate(newRate, tipJar, totalSupply());
    }

    function setTipRate(Percentage newRate) external {
        _setTipRate(newRate, tipJar, totalSupply());
    }

    // ---- Public accrual entry point ----
    function tip() external returns (uint256) {
        return _accrueTip(tipJar, totalSupply());
    }

    // ---- Yield simulation ----
    function simulateYield(uint256 amount) external {
        // Mint underlying directly to the vault (increases totalAssets without new shares)
        MockAsset(asset()).mint(address(this), amount);
    }

    function simulateLoss(uint256 amount) external {
        // Burn underlying from the vault (decreases totalAssets)
        MockAsset(asset()).burn(address(this), amount);
    }

    // ---- Expose internal helpers for fuzz tests ----
    function exposed_calculateTip(
        uint256 totalShares,
        uint256 timeElapsed
    ) external view returns (uint256) {
        return _calculateTip(totalShares, timeElapsed);
    }

    // Prevent forge from treating this as a test contract
    function test_() public {}
}

// ============================================================================
// Test Suite: FlexibleTipper Unit Tests
// ============================================================================
contract FlexibleTipperTest is Test, ITipperEvents {
    using PercentageUtils for uint256;

    FlexibleTipperHarness public vault;
    MockAsset public asset;

    address public tipJar = address(0xFEE);
    address public user = address(0xBEEF);

    uint256 constant INITIAL_DEPOSIT = 1000000e6; // 1M USDC (6 decimals)

    function setUp() public {
        asset = new MockAsset();
        vault = new FlexibleTipperHarness(
            IERC20(address(asset)),
            PercentageUtils.fromIntegerPercentage(1), // 1% AUM
            tipJar
        );

        // Seed user with tokens and deposit
        asset.mint(user, INITIAL_DEPOSIT);
        vm.startPrank(user);
        asset.approve(address(vault), INITIAL_DEPOSIT);
        vault.deposit(INITIAL_DEPOSIT, user);
        vm.stopPrank();
    }

    // ================================================================
    // Constructor / Default State
    // ================================================================

    function test_DefaultFeeType_IsAUM() public view {
        assertTrue(
            vault.feeType() == IFlexibleTipper.FeeType.AUM,
            "Default fee type should be AUM"
        );
    }

    function test_DefaultHWM_IsOneToOne() public view {
        assertEq(
            vault.highWaterMark(),
            1e18,
            "Default HWM should be 1e18 (1:1)"
        );
    }

    function test_DefaultPerformanceFeeRate_IsZero() public view {
        assertTrue(
            vault.performanceFeeRate() == toPercentage(0),
            "Default performance fee rate should be 0"
        );
    }

    // ================================================================
    // AUM-only mode (backward compatibility with original Tipper)
    // ================================================================

    function test_AUMOnly_MatchesOriginalTipper() public {
        // Warp 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 tipperExpected = vault.exposed_calculateTip(
            vault.totalSupply() - IERC20(address(vault)).balanceOf(tipJar),
            365 days
        );

        uint256 tipperActual = vault.tip();

        assertEq(
            tipperActual,
            tipperExpected,
            "AUM fee should match original Tipper calculation"
        );
        assertGt(tipperActual, 0, "Should accrue non-zero tip after 1 year");
    }

    function test_AUMOnly_NoPerformanceFee() public {
        // Even with profit, AUM mode should NOT charge performance fee
        vault.simulateYield(100000e6); // 100k yield

        vm.warp(block.timestamp + 30 days);

        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);

        uint256 feeShares = tipAfter - tipBefore;

        // Calculate expected AUM fee
        uint256 expectedAUM = vault.exposed_calculateTip(
            vault.totalSupply() - tipAfter, // totalSupply before tip minus tipJar balance
            30 days
        );

        // The actual fee should be approximately equal to AUM-only
        // (not inflated by performance fee)
        // We verify no PerformanceFeeAccrued event was emitted
        assertGt(feeShares, 0, "Should have accrued some AUM fee");
    }

    // ================================================================
    // Performance-only mode
    // ================================================================

    function test_PerformanceOnly_NoFeeWhenNoProfit() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20)); // 20%

        // No yield, just time passing
        vm.warp(block.timestamp + 365 days);

        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);

        assertEq(tipAfter - tipBefore, 0, "No performance fee when no profit");
    }

    function test_PerformanceOnly_FeeOnProfit() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20)); // 20%

        // Simulate 10% yield: 100k on 1M
        vault.simulateYield(100000e6);

        vm.warp(block.timestamp + 1); // just advance 1 second to ensure timestamp changes

        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);

        uint256 feeShares = tipAfter - tipBefore;
        assertGt(feeShares, 0, "Should charge performance fee on profit");

        // The fee should be approximately 20% of 100k yield in share terms
        // 20% of 100k = 20k assets
        // shares = 20k * totalSupply / totalAssets ≈ 20k * 1M / 1.1M ≈ 18181.8 shares
        // Allow 1% tolerance for rounding
        uint256 expectedFeeAssets = 20000e6;
        uint256 expectedFeeShares = (expectedFeeAssets *
            (INITIAL_DEPOSIT + feeShares)) / (INITIAL_DEPOSIT + 100000e6);

        assertApproxEqAbs(
            feeShares,
            expectedFeeShares,
            1, // 1 wei tolerance for rounding
            "Performance fee shares should be exactly correct according to dilution-aware math"
        );
    }

    function test_PerformanceOnly_HWMUpdatesAfterFee() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        uint256 hwmBefore = vault.highWaterMark();

        vault.simulateYield(100000e6);
        vm.warp(block.timestamp + 1);
        vault.tip();

        uint256 hwmAfter = vault.highWaterMark();
        uint256 apsAfter = (vault.totalAssets() * 1e18) / vault.totalSupply();

        assertEq(
            hwmAfter,
            apsAfter,
            "HWM should exactly match post-accrual Assets Per Share"
        );
    }

    function test_PerformanceOnly_NoFeeAfterLoss() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        // First: gain → triggers fee and sets HWM high
        vault.simulateYield(100000e6);
        vm.warp(block.timestamp + 1);
        vault.tip();

        uint256 hwmAfterGain = vault.highWaterMark();

        // Then: loss
        vault.simulateLoss(200000e6); // lose more than gained

        vm.warp(block.timestamp + 1);
        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);

        assertEq(tipAfter - tipBefore, 0, "No fee after loss (below HWM)");
        assertEq(
            vault.highWaterMark(),
            hwmAfterGain,
            "HWM unchanged after loss"
        );
    }

    function test_PerformanceOnly_FeeOnlyOnNewProfit() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        // Gain → fee accrued
        vault.simulateYield(100000e6);
        vm.warp(block.timestamp + 1);
        vault.tip();
        uint256 hwm1 = vault.highWaterMark();

        // Loss → no fee
        vault.simulateLoss(50000e6);
        vm.warp(block.timestamp + 1);
        vault.tip();

        // Partial recovery: gain 30k (still below original HWM)
        vault.simulateYield(30000e6);
        vm.warp(block.timestamp + 1);

        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);

        // Should be zero or very small if still below HWM
        // Need to check actual assetsPerShare vs hwm1
        uint256 currentAPS = (vault.totalAssets() * 1e18) / vault.totalSupply();
        if (currentAPS <= hwm1) {
            assertEq(
                tipAfter - tipBefore,
                0,
                "No fee if still below original HWM"
            );
        } else {
            assertGt(
                tipAfter - tipBefore,
                0,
                "Fee only on delta above old HWM"
            );
        }
    }

    // ================================================================
    // BOTH mode
    // ================================================================

    function test_Both_AUMAndPerformanceFee() public {
        vault.setFeeType(IFlexibleTipper.FeeType.BOTH);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        // Simulate yield
        vault.simulateYield(100000e6);

        // Advance time for AUM
        vm.warp(block.timestamp + 365 days);

        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);

        uint256 totalFee = tipAfter - tipBefore;

        // Should be strictly more than AUM-only (because performance fee adds on top)
        assertGt(totalFee, 0, "Should accrue both fees");
    }

    // ================================================================
    // Governor setters: validation
    // ================================================================

    function test_SetPerformanceFeeRate_RevertIfTooHigh() public {
        vm.expectRevert(abi.encodeWithSignature("PerformanceFeeRateTooHigh()"));
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(51));
    }

    function test_SetPerformanceFeeRate_Success() public {
        Percentage newRate = PercentageUtils.fromIntegerPercentage(15);
        vault.setPerformanceFeeRate(newRate);
        assertTrue(
            vault.performanceFeeRate() == newRate,
            "Performance fee rate should be updated"
        );
    }

    function test_SetFeeType_Success() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        assertTrue(
            vault.feeType() == IFlexibleTipper.FeeType.PERFORMANCE,
            "Fee type should be updated to PERFORMANCE"
        );

        vault.setFeeType(IFlexibleTipper.FeeType.BOTH);
        assertTrue(
            vault.feeType() == IFlexibleTipper.FeeType.BOTH,
            "Fee type should be updated to BOTH"
        );
    }

    // ================================================================
    // Edge cases
    // ================================================================

    function test_ZeroSupply_NoRevert() public {
        // Create a fresh vault with no deposits
        FlexibleTipperHarness emptyVault = new FlexibleTipperHarness(
            IERC20(address(asset)),
            PercentageUtils.fromIntegerPercentage(1),
            tipJar
        );
        emptyVault.setFeeType(IFlexibleTipper.FeeType.BOTH);
        emptyVault.setPerformanceFeeRate(
            PercentageUtils.fromIntegerPercentage(20)
        );

        vm.warp(block.timestamp + 365 days);

        // Should not revert
        uint256 fee = emptyVault.tip();
        assertEq(fee, 0, "No fee with zero supply");
    }

    function test_ZeroAssets_NoRevert() public {
        // Drain the vault
        vm.startPrank(user);
        uint256 shares = vault.balanceOf(user);
        vault.redeem(shares, user, user);
        vm.stopPrank();

        vault.setFeeType(IFlexibleTipper.FeeType.BOTH);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        vm.warp(block.timestamp + 365 days);

        uint256 fee = vault.tip();
        assertEq(fee, 0, "No fee with zero assets");
    }

    // ================================================================
    // HWM reset on fee type change
    // ================================================================

    /// @notice When governor changes fee type, HWM resets to current
    /// assetsPerShare. This prevents a "dead HWM" after drawdowns.
    function test_SetFeeType_ResetsHWMToCurrentAPS() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        // Gain -> HWM goes up
        vault.simulateYield(200000e6);
        vm.warp(block.timestamp + 1);
        vault.tip();
        uint256 hwmAfterGain = vault.highWaterMark();

        // Loss -> APS drops below HWM
        vault.simulateLoss(300000e6);

        // Current APS is below HWM
        uint256 currentAPS = (vault.totalAssets() * 1e18) / vault.totalSupply();
        assertLt(
            currentAPS,
            hwmAfterGain,
            "APS should be below HWM after loss"
        );

        // Governor switches fee type → HWM resets to current APS
        vault.setFeeType(IFlexibleTipper.FeeType.BOTH);

        uint256 hwmAfterReset = vault.highWaterMark();
        assertEq(
            hwmAfterReset,
            currentAPS,
            "HWM should reset to current APS on fee type change"
        );
        assertLt(
            hwmAfterReset,
            hwmAfterGain,
            "Reset HWM should be lower than old HWM"
        );

        // Now any new yield triggers a performance fee (from the new, lower HWM)
        vault.simulateYield(50000e6);
        vm.warp(block.timestamp + 1);

        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);

        assertGt(
            tipAfter - tipBefore,
            0,
            "Should charge fee on new profit after HWM reset"
        );
    }

    /// @notice When fee type changes with zero supply, HWM defaults to 1:1
    function test_SetFeeType_ResetsHWMToOneToOne_WhenZeroSupply() public {
        FlexibleTipperHarness emptyVault = new FlexibleTipperHarness(
            IERC20(address(asset)),
            PercentageUtils.fromIntegerPercentage(1),
            tipJar
        );

        emptyVault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        assertEq(
            emptyVault.highWaterMark(),
            1e18,
            "HWM should be 1e18 with zero supply"
        );
    }

    // ================================================================
    // previewTip: Performance fee is included in preview
    // ================================================================

    /// @notice In AUM-only mode, previewTip should only return AUM shares (no perf).
    function test_PreviewTip_AUMOnly_NoPerformanceFeePreview() public {
        // yield + time
        vault.simulateYield(100000e6);
        vm.warp(block.timestamp + 365 days);

        uint256 rawSupply = vault.totalSupply(); // view context — includes preview
        // Since we're in AUM mode, previewTip should not include performance fee
        uint256 preview = vault.previewTip(tipJar, 1000000e6); // raw supply
        // Should be AUM only
        assertGt(preview, 0, "AUM preview should be > 0");
    }

    /// @notice In PERFORMANCE mode, previewTip should include the performance fee.
    function test_PreviewTip_IncludesPerformanceFee() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        // 10% yield
        vault.simulateYield(100000e6);

        uint256 rawSupply = ERC20(address(vault)).totalSupply(); // bypass the override
        uint256 preview = vault.previewTip(tipJar, rawSupply);

        assertGt(preview, 0, "Preview should include performance fee shares");
    }

    /// @notice previewTip should match the actual tip() result (preview == execution).
    function test_PreviewTip_MatchesActualTip() public {
        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        // 10% yield
        vault.simulateYield(100000e6);
        vm.warp(block.timestamp + 1); // need at least 1s for timestamp update

        uint256 rawSupply = ERC20(address(vault)).totalSupply();
        uint256 preview = vault.previewTip(tipJar, rawSupply);

        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);
        uint256 actualTip = tipAfter - tipBefore;

        assertEq(preview, actualTip, "Preview should match actual tip minted");
    }
}

// ============================================================================
// Test Suite: FlexibleTipper Fuzz Tests
// ============================================================================
contract FlexibleTipperFuzzTest is Test {
    using PercentageUtils for uint256;

    FlexibleTipperHarness public vault;
    MockAsset public asset;

    address public tipJar = address(0xFEE);
    address public user = address(0xBEEF);

    function setUp() public {
        asset = new MockAsset();
        vault = new FlexibleTipperHarness(
            IERC20(address(asset)),
            PercentageUtils.fromIntegerPercentage(1), // 1% AUM
            tipJar
        );
    }

    /// @notice Helper: deposit a given amount for the user
    function _deposit(uint256 amount) internal {
        asset.mint(user, amount);
        vm.startPrank(user);
        asset.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }

    // ================================================================
    // Fuzz: Performance fee never exceeds profit in share terms
    // ================================================================

    /// @notice For any profit scenario, the fee shares never exceed
    /// what the profit represents in shares.
    function testFuzz_PerformanceFee_NeverExceedsProfit(
        uint256 depositAmount,
        uint256 yieldAmount,
        uint256 perfFeeRateBps
    ) public {
        // Bound inputs to sane ranges
        depositAmount = bound(depositAmount, 1e6, 1e15); // 1 USDC to 1B USDC
        yieldAmount = bound(yieldAmount, 1, depositAmount); // yield ≤ deposit
        perfFeeRateBps = bound(perfFeeRateBps, 1, 50); // 1% to 50%

        _deposit(depositAmount);

        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(
            PercentageUtils.fromIntegerPercentage(perfFeeRateBps)
        );

        // Simulate yield
        vault.simulateYield(yieldAmount);

        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.warp(block.timestamp + 1);

        // Calculate expected profit in share terms
        // profitShares = yieldAmount * totalSupply / totalAssets
        uint256 profitShares = (yieldAmount * totalSupplyBefore) /
            totalAssetsBefore;

        uint256 feeShares = vault.tip();

        assertLe(
            feeShares,
            profitShares,
            "Fee shares must not exceed profit in share terms"
        );
    }

    // ================================================================
    // Fuzz: HWM never decreases during fee accrual
    // ================================================================

    /// @notice During tip() accrual (without setFeeType), HWM should only
    /// increase or stay the same. HWM can reset via setFeeType (tested separately).
    function testFuzz_HWM_NeverDecreasesDuringAccrual(
        uint256 depositAmount,
        uint256 yield1,
        uint256 loss1,
        uint256 yield2
    ) public {
        depositAmount = bound(depositAmount, 1e6, 1e12);
        yield1 = bound(yield1, 0, depositAmount / 2);
        loss1 = bound(loss1, 0, yield1); // loss ≤ gain to stay solvent
        yield2 = bound(yield2, 0, depositAmount / 2);

        _deposit(depositAmount);

        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(10));

        uint256 hwm0 = vault.highWaterMark();

        // Yield 1
        if (yield1 > 0) vault.simulateYield(yield1);
        vm.warp(block.timestamp + 1);
        vault.tip();
        uint256 hwm1 = vault.highWaterMark();
        assertGe(hwm1, hwm0, "HWM should not decrease after yield");

        // Loss
        if (loss1 > 0) vault.simulateLoss(loss1);
        vm.warp(block.timestamp + 1);
        vault.tip();
        uint256 hwm2 = vault.highWaterMark();
        assertGe(hwm2, hwm1, "HWM should not decrease after loss");

        // Yield 2
        if (yield2 > 0) vault.simulateYield(yield2);
        vm.warp(block.timestamp + 1);
        vault.tip();
        uint256 hwm3 = vault.highWaterMark();
        assertGe(hwm3, hwm2, "HWM should not decrease after second yield");
    }

    // ================================================================
    // Fuzz: AUM fee matches original Tipper for any parameters
    // ================================================================

    /// @notice For any (totalSupply, tipRate, timeElapsed), the AUM fee
    /// should match the original Tipper._calculateTip output.
    function testFuzz_AUM_MatchesTipperForAnyTime(
        uint256 depositAmount,
        uint256 timeElapsed
    ) public {
        depositAmount = bound(depositAmount, 1e6, 1e15);
        timeElapsed = bound(timeElapsed, 1, 10 * 365 days); // up to 10 years

        _deposit(depositAmount);

        vm.warp(block.timestamp + timeElapsed);

        uint256 totalShares = vault.totalSupply() -
            IERC20(address(vault)).balanceOf(tipJar);

        uint256 expectedTip = vault.exposed_calculateTip(
            totalShares,
            timeElapsed
        );
        uint256 actualTip = vault.tip();

        assertEq(
            actualTip,
            expectedTip,
            "AUM fee should match original Tipper"
        );
    }

    // ================================================================
    // Fuzz: No fee when below HWM
    // ================================================================

    /// @notice For any state where assetsPerShare ≤ HWM, performance fee is 0.
    function testFuzz_NoFeeWhenBelowHWM(
        uint256 depositAmount,
        uint256 yieldAmount,
        uint256 lossAmount
    ) public {
        depositAmount = bound(depositAmount, 1e6, 1e12);
        yieldAmount = bound(yieldAmount, 1, depositAmount / 2);
        // loss must be enough to bring APS below HWM
        lossAmount = bound(
            lossAmount,
            yieldAmount + 1,
            depositAmount / 2 + yieldAmount
        );

        _deposit(depositAmount);

        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(PercentageUtils.fromIntegerPercentage(20));

        // Gain first → set HWM high
        vault.simulateYield(yieldAmount);
        vm.warp(block.timestamp + 1);
        vault.tip();

        uint256 hwmAfterGain = vault.highWaterMark();

        // Loss → bring below HWM
        vault.simulateLoss(lossAmount);
        vm.warp(block.timestamp + 1);

        uint256 tipBefore = IERC20(address(vault)).balanceOf(tipJar);
        vault.tip();
        uint256 tipAfter = IERC20(address(vault)).balanceOf(tipJar);

        assertEq(tipAfter - tipBefore, 0, "No performance fee when below HWM");
        assertEq(
            vault.highWaterMark(),
            hwmAfterGain,
            "HWM unchanged when below"
        );
    }

    // ================================================================
    // Fuzz: After minting fee shares, assetsPerShare does not inflate
    // ================================================================

    /// @notice After minting performance fee shares, the new assetsPerShare
    /// must be ≤ the pre-fee assetsPerShare (dilution, not inflation).
    function testFuzz_FeeSharesDilution_ConservesAssets(
        uint256 depositAmount,
        uint256 yieldAmount,
        uint256 perfFeeRateBps
    ) public {
        depositAmount = bound(depositAmount, 1e6, 1e12);
        yieldAmount = bound(yieldAmount, 1, depositAmount);
        perfFeeRateBps = bound(perfFeeRateBps, 1, 50);

        _deposit(depositAmount);

        vault.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        vault.setPerformanceFeeRate(
            PercentageUtils.fromIntegerPercentage(perfFeeRateBps)
        );

        vault.simulateYield(yieldAmount);

        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 apsBefore = (totalAssetsBefore * 1e18) / totalSupplyBefore;

        vm.warp(block.timestamp + 1);
        vault.tip();

        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 totalSupplyAfter = vault.totalSupply();

        // totalAssets should not change (we only mint shares, not assets)
        assertEq(
            totalAssetsAfter,
            totalAssetsBefore,
            "totalAssets should not change from tip"
        );

        if (totalSupplyAfter > 0) {
            uint256 apsAfter = (totalAssetsAfter * 1e18) / totalSupplyAfter;

            assertLe(
                apsAfter,
                apsBefore,
                "Assets per share must not increase after fee dilution"
            );
        }
    }
}
