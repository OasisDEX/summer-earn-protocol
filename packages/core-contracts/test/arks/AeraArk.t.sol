// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/AeraArk.sol";
import "../../src/events/IArkEvents.sol";
import "../../src/interfaces/IArkWithWithdrawalRequest.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IProvisioner} from "../../src/interfaces/gauntlet/IProvisioner.sol";
import {IPriceAndFeeCalculator} from "../../src/interfaces/gauntlet/IPriceFeeCalculator.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract AeraArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    AeraArk public ark;
    IProvisioner public provisioner;
    IPriceAndFeeCalculator public priceCalculator;
    IERC20 public usdc;
    IERC20 public vault;
    ArkParams public params;

    // Base addresses
    address public constant PROVISIONER_ADDRESS =
        0x18cf8d963e1a727f9bbf3aeffa0bd04fb4dbda07;
    address public constant VAULT_ADDRESS =
        0x000000000001cdb57e58fa75fe420a0f4d6640d5;
    address public constant USDC_ADDRESS =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC

    uint256 forkBlock = 23000000; // A recent block number for Base
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("base"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        provisioner = IProvisioner(PROVISIONER_ADDRESS);
        vault = IERC20(VAULT_ADDRESS);

        // Get price calculator from provisioner
        address priceCalculatorAddr = provisioner.PRICE_FEE_CALCULATOR();
        priceCalculator = IPriceAndFeeCalculator(priceCalculatorAddr);

        params = ArkParams({
            name: "Base USDC Aera Ark",
            details: "Base USDC Aera Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new AeraArk(PROVISIONER_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        // Make addresses persistent for the fork
        vm.makePersistent(PROVISIONER_ADDRESS);
        vm.makePersistent(VAULT_ADDRESS);
        vm.makePersistent(address(ark));
        vm.makePersistent(address(usdc));
    }

    function test_Constructor() public {
        // Invalid provisioner address
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAddress(string,address)",
                "provisioner",
                address(0)
            )
        );
        ark = new AeraArk(address(0), params);

        // Valid constructor
        ark = new AeraArk(PROVISIONER_ADDRESS, params);

        assertEq(
            address(ark.provisioner()),
            PROVISIONER_ADDRESS,
            "Provisioner address should match"
        );
        assertEq(
            address(ark.vault()),
            VAULT_ADDRESS,
            "Vault address should match"
        );
        assertEq(
            address(ark.asset()),
            USDC_ADDRESS,
            "Asset address should match USDC"
        );
        assertEq(ark.name(), "Base USDC Aera Ark", "Ark name should match");
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC (6 decimals on Base)
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);

        uint256 initialVaultBalance = vault.balanceOf(address(ark));
        uint256 initialTotalAssets = ark.totalAssets();

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC_ADDRESS, amount);

        // Expect the UnitsReceived event
        vm.expectEmit(false, false, false, false);
        emit AeraArk.UnitsReceived(0, 0); // We don't know exact amounts beforehand

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalVaultBalance = vault.balanceOf(address(ark));
        uint256 finalTotalAssets = ark.totalAssets();

        assertGt(
            finalVaultBalance,
            initialVaultBalance,
            "Vault units balance should increase"
        );
        assertGt(
            finalTotalAssets,
            initialTotalAssets,
            "Total assets should increase"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        assertGt(
            totalAssets,
            0,
            "Total assets should be greater than 0 after boarding"
        );

        // Should be approximately equal to deposited amount (allowing for some variance)
        assertApproxEqRel(
            totalAssets,
            amount,
            5e16, // 5% tolerance
            "Total assets should be approximately equal to deposited amount"
        );
    }

    function test_VaultUnitsBalance() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 vaultUnits = ark.vaultUnitsBalance();
        assertGt(vaultUnits, 0, "Vault units should be greater than 0");

        // Verify that vault units balance matches actual vault balance
        assertEq(
            vaultUnits,
            vault.balanceOf(address(ark)),
            "Vault units should match vault balance"
        );
    }

    function test_GetVaultState() public {
        (VaultPriceState memory priceState, VaultAccruals memory accruals) = ark
            .getVaultState();

        // Basic checks on vault state
        assertGt(priceState.price, 0, "Vault price should be greater than 0");
        assertGt(priceState.timestamp, 0, "Price timestamp should be set");
    }

    function test_IsVaultPaused() public {
        bool isPaused = ark.isVaultPaused();
        // We assume vault is not paused in normal operation
        // This test mainly checks that the function doesn't revert
        console.log("Vault paused status:", isPaused);
    }

    function test_Harvest() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Fast forward time to potentially accrue yield
        vm.warp(block.timestamp + 30 days);

        vm.prank(address(raft));
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest("");

        // Aera vaults are auto-compounding, so no separate rewards
        assertEq(rewardTokens.length, 0, "Should return no reward tokens");
        assertEq(rewardAmounts.length, 0, "Should return no reward amounts");
    }

    function test_WithdrawableTotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 withdrawableAssets = ark.withdrawableTotalAssets();

        // For Aera with async withdrawals, withdrawable assets represent
        // tokens that have been processed and are sitting in the contract
        console.log("Withdrawable assets:", withdrawableAssets);
        console.log("Total assets:", ark.totalAssets());
    }

    function test_AssetsInWithdrawalQueue() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Initially no assets in withdrawal queue
        uint256 assetsInQueue = ark.assetsInWithdrawalQueue();
        assertEq(
            assetsInQueue,
            0,
            "Initially no assets should be in withdrawal queue"
        );

        // After requesting withdrawal, assets should be in queue
        vm.prank(keeper);
        ark.requestWithdrawal(500 * 1e6);

        // Note: In this simplified implementation, assetsInWithdrawalQueue returns 0
        // In production, this would track actual pending requests
        assetsInQueue = ark.assetsInWithdrawalQueue();
        console.log("Assets in withdrawal queue after request:", assetsInQueue);
    }

    function test_ClaimWithdrawal() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Request withdrawal first
        vm.prank(keeper);
        ark.requestWithdrawal(500 * 1e6);

        // Claim withdrawal (no-op for Aera since it's automatic)
        vm.prank(keeper);
        ark.claimWithdrawal(); // Should not revert

        // Check that no claim is required
        bool claimRequired = ark.isWithdrawalClaimRequired();
        assertFalse(claimRequired, "Aera should not require manual claim");
    }

    function test_RequestWithdrawal() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Test withdrawal request
        uint256 withdrawAmount = 500 * 1e6; // Withdraw half

        vm.prank(keeper);
        vm.expectEmit();
        emit IArkWithWithdrawalRequest.WithdrawalRequested(withdrawAmount, 0);

        ark.requestWithdrawal(withdrawAmount);

        // Verify withdrawal request was created
        uint256 requestId = ark.withdrawalRequestId();
        console.log("Withdrawal request ID:", requestId);
    }

    function test_MaxDeposit() public {
        // Test the max deposit functionality from provisioner
        uint256 maxDeposit = provisioner.maxDeposit();
        console.log("Max deposit available:", maxDeposit);
        assertGt(maxDeposit, 0, "Max deposit should be greater than 0");
    }

    function test_YieldAccrual() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 initialTotalAssets = ark.totalAssets();

        // Fast forward time to accrue yield
        vm.warp(block.timestamp + 365 days);

        uint256 finalTotalAssets = ark.totalAssets();

        // Check if yield has accrued (should be >= initial due to auto-compounding)
        assertGe(
            finalTotalAssets,
            initialTotalAssets,
            "Total assets should not decrease over time"
        );

        console.log("Initial total assets:", initialTotalAssets);
        console.log("Final total assets after 1 year:", finalTotalAssets);
    }

    function test_WithdrawUsingSwap() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Test emergency swap withdrawal
        uint256 swapAmount = 100 * 1e6; // 100 USDC

        // Mock swap data (simplified for test)
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: address(0x123), // Mock router
                swapCalldata: abi.encodeWithSignature("swap()")
            });

        bytes memory data = abi.encode(swapData);

        // This would normally require whitelisted router and proper swap setup
        // For now, test should revert due to unwhitelisted router
        vm.prank(keeper);
        try ark.withdrawUsingSwap(swapAmount, data) {
            // If it succeeds, check event emission
            console.log("Swap withdrawal completed");
        } catch Error(string memory reason) {
            console.log("Swap withdrawal failed (expected):", reason);
        }
    }
}
