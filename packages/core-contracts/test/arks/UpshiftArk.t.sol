// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/UpshiftArk.sol";
import "../../src/events/IArkEvents.sol";
import "../../src/interfaces/upshift/IUpshiftVault.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract UpshiftArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    UpshiftArk public ark;
    UpshiftArk public arkWithLag;
    IUpshiftVault public vault;
    IUpshiftVault public vaultWithLag;
    IERC20 public usdc;
    ArkParams public params;

    address public constant VAULT_ADDRESS =
        0xE9B725010A9E419412ed67d0fA5f3A5f40159D32;
    address public constant VAULT_WITH_LAG_ADDRESS =
        0xdA89af5bF2eb0B225d787aBfA9095610f2E79e7D;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), 24540718);

        usdc = IERC20(USDC_ADDRESS);
        vault = IUpshiftVault(VAULT_ADDRESS);
        vaultWithLag = IUpshiftVault(VAULT_WITH_LAG_ADDRESS);

        params = ArkParams({
            name: "USDC Upshift Ark",
            details: "USDC Upshift Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new UpshiftArk(VAULT_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantKeeperRole(address(address(ark)), address(keeper));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        // Also setup the second ark with lag
        ArkParams memory paramsLag = ArkParams({
            name: "USDC Upshift Ark With Lag",
            details: "USDC Upshift Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        arkWithLag = new UpshiftArk(VAULT_WITH_LAG_ADDRESS, paramsLag);

        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(arkWithLag)),
            address(commander)
        );
        accessManager.grantKeeperRole(
            address(address(arkWithLag)),
            address(keeper)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        arkWithLag.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor() public {
        assertEq(
            address(ark.vault()),
            VAULT_ADDRESS,
            "Vault address should match"
        );
        assertEq(
            address(ark.asset()),
            USDC_ADDRESS,
            "Token address should match USDC"
        );
        assertEq(ark.name(), "USDC Upshift Ark", "Ark name should match");
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 initialVaultBalance = vault.balanceOf(address(ark));

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC_ADDRESS, amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalVaultBalance = vault.balanceOf(address(ark));
        assertGt(
            finalVaultBalance,
            initialVaultBalance,
            "Vault balance should increase"
        );
    }

    function test_RequestWithdrawalAndClaim() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 assetsBefore = ark.totalAssets();

        assertEq(
            ark.assetsInWithdrawalQueue(),
            0,
            "Should not have pending claim"
        );

        // Request Withdrawal
        vm.startPrank(keeper);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        uint256 inQueue = ark.assetsInWithdrawalQueue();
        uint256 lagDuration = vault.lagDuration();
        assertEq(lagDuration, 0, "Lag duration should be 0");

        assertApproxEqRel(
            assetsBefore,
            ark.totalAssets(),
            1e10,
            "Total assets should remain stable after request"
        );

        if (inQueue > 0) {
            vm.startPrank(keeper);
            vm.expectRevert(
                abi.encodeWithSignature("PendingWithdrawalExists()")
            );
            ark.requestWithdrawal(amount);
            vm.stopPrank();
        }

        if (inQueue > 0) {
            bool requiresClaim = ark.isWithdrawalClaimRequired();
            if (!requiresClaim) {
                (, uint256 executionEpoch) = vault
                    .getScheduledTransactionsByDate(
                        ark.pendingClaimYear(),
                        ark.pendingClaimMonth(),
                        ark.pendingClaimDay()
                    );
                vm.warp(executionEpoch + 6 minutes);
            }
            assertTrue(
                ark.isWithdrawalClaimRequired(),
                "Claim should be required now"
            );
        }

        uint256 usdcBalanceBeforeClaim = usdc.balanceOf(address(ark));

        // Claim
        vm.startPrank(keeper);
        ark.claimWithdrawal();
        vm.stopPrank();

        assertEq(ark.assetsInWithdrawalQueue(), 0, "Queue should be empty");

        uint256 usdcBalanceAfterClaim = usdc.balanceOf(address(ark));

        if (inQueue > 0) {
            assertGt(
                usdcBalanceAfterClaim,
                usdcBalanceBeforeClaim,
                "Ark should have received USDC from claim"
            );
        }

        assertApproxEqRel(
            assetsBefore,
            ark.totalAssets(),
            1e10,
            "Total assets should remain stable after claim"
        );
    }

    function test_RequestWithdrawalAndClaim_Lag() public {
        uint256 amount = 1000 * 1e6;

        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(arkWithLag), amount);
        arkWithLag.board(amount, bytes(""));
        vm.stopPrank();

        uint256 assetsBefore = arkWithLag.totalAssets();

        assertEq(
            arkWithLag.assetsInWithdrawalQueue(),
            0,
            "Should not have pending claim"
        );

        // Request Withdrawal
        vm.startPrank(keeper);
        arkWithLag.requestWithdrawal(amount);
        vm.stopPrank();

        uint256 inQueue = arkWithLag.assetsInWithdrawalQueue();
        assertGt(inQueue, 0, "Should have pending claim");

        uint256 lagDuration = vaultWithLag.lagDuration();
        assertGt(lagDuration, 0, "Lag duration should be greater than 0");
        assertGt(inQueue, 0, "Assets should remain in queue for lag vault");
        assertApproxEqRel(
            assetsBefore,
            arkWithLag.totalAssets(),
            1e10,
            "Total assets should remain stable after request"
        );

        assertFalse(
            arkWithLag.isWithdrawalClaimRequired(),
            "Claim should not be required immediately"
        );

        (, uint256 executionEpoch) = vaultWithLag
            .getScheduledTransactionsByDate(
                arkWithLag.pendingClaimYear(),
                arkWithLag.pendingClaimMonth(),
                arkWithLag.pendingClaimDay()
            );

        // Advance the blockchain time precisely to executionEpoch, which intrinsically includes the 3-day lagDuration
        // We add 6 minutes to clear Upshift's internal 5-minute timestamp manipulation buffer
        vm.warp(executionEpoch + 6 minutes);

        assertTrue(
            arkWithLag.isWithdrawalClaimRequired(),
            "Claim should be required now!"
        );

        uint256 usdcBalanceBeforeClaim = usdc.balanceOf(address(arkWithLag));

        // Let's claim
        vm.startPrank(keeper);
        arkWithLag.claimWithdrawal();
        vm.stopPrank();

        assertEq(
            arkWithLag.assetsInWithdrawalQueue(),
            0,
            "Queue should be empty"
        );

        uint256 usdcBalanceAfterClaim = usdc.balanceOf(address(arkWithLag));

        assertGt(
            usdcBalanceAfterClaim,
            usdcBalanceBeforeClaim,
            "Ark should have received USDC from claim"
        );

        assertApproxEqRel(
            assetsBefore,
            arkWithLag.totalAssets(),
            1e10,
            "Total assets should remain stable after claim"
        );
    }

    function test_RequestWithdrawalAndClaim_Lag_AutoProcessed() public {
        uint256 amount = 1000 * 1e6;

        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(arkWithLag), amount);
        arkWithLag.board(amount, bytes(""));
        vm.stopPrank();

        uint256 assetsBefore = arkWithLag.totalAssets();

        assertEq(
            arkWithLag.assetsInWithdrawalQueue(),
            0,
            "Should not have pending claim"
        );

        // Request Withdrawal
        vm.startPrank(keeper);
        arkWithLag.requestWithdrawal(amount);
        vm.stopPrank();

        uint256 inQueue = arkWithLag.assetsInWithdrawalQueue();
        assertGt(inQueue, 0, "Should have pending claim");

        uint256 lagDuration = vaultWithLag.lagDuration();
        assertGt(lagDuration, 0, "Lag duration should be greater than 0");

        (, uint256 executionEpoch) = vaultWithLag
            .getScheduledTransactionsByDate(
                arkWithLag.pendingClaimYear(),
                arkWithLag.pendingClaimMonth(),
                arkWithLag.pendingClaimDay()
            );

        // To simulate the operator, we warp directly to the execution epoch.
        vm.warp(executionEpoch);

        // Since we are not running the full off-chain strategy rebalance, we deal USDC to the vault manually
        // We deal a massive amount because the vault processes ALL claims for that epoch on the mainnet fork,
        // which could be millions of USDC.
        deal(USDC_ADDRESS, address(vaultWithLag), 100000000 * 1e6);

        // Upshift vaults allow permissionless processing of all claims for a given date once the lag passes
        vaultWithLag.processAllClaimsByDate(
            arkWithLag.pendingClaimYear(),
            arkWithLag.pendingClaimMonth(),
            arkWithLag.pendingClaimDay(),
            100 // Process limit
        );

        // Advance the blockchain time an extra 6 minutes past the epoch
        vm.warp(executionEpoch + 6 minutes);

        // Claim should no longer be required
        assertFalse(
            arkWithLag.isWithdrawalClaimRequired(),
            "Claim should NOT be required since operator processed it"
        );

        uint256 usdcBalanceBeforeClaim = usdc.balanceOf(address(arkWithLag));

        // Calling claimWithdrawal should essentially be a no-op
        vm.startPrank(keeper);
        arkWithLag.claimWithdrawal();
        vm.stopPrank();

        assertEq(
            arkWithLag.assetsInWithdrawalQueue(),
            0,
            "Queue should be empty"
        );

        uint256 usdcBalanceAfterClaim = usdc.balanceOf(address(arkWithLag));
        assertEq(
            usdcBalanceAfterClaim,
            usdcBalanceBeforeClaim,
            "Ark should have unchanged USDC balance"
        );

        assertApproxEqRel(
            assetsBefore,
            arkWithLag.totalAssets(),
            1e10,
            "Total assets should remain stable after claim"
        );
    }
}
