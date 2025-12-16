// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/MidasArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDepositVault} from "../../src/interfaces/midas/IDepositVault.sol";
import {IRedemptionVault} from "../../src/interfaces/midas/IRedemptionVault.sol";
import {IMidasOracle} from "../../src/interfaces/midas/IMidasOracle.sol";
import {IMidasWithdrawalManager} from "../../src/interfaces/midas/IMidasWithdrawalManager.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract MidasArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;
    MidasArk public ark;
    IMidasWithdrawalManager public withdrawalManager;
    address public bufferArk;

    // Midas addresses
    address public constant MIDAS_VAULT_ADDRESS =
        0x7CF9DEC92ca9FD46f8d86e7798B72624Bc116C05;
    address public constant MIDAS_ISSUANCE_VAULT_ADDRESS =
        0xc21511EDd1E6eCdc36e8aD4c82117033e50D5921;
    address public constant MIDAS_REDEMPTION_VAULT_ADDRESS =
        0x5aeA6D35ED7B3B7aE78694B7da2Ee880756Af5C0;

    // TODO: Determine the underlying asset address (USDC/USDT/etc) from the vault
    // This will need to be set based on the actual Midas vault configuration
    address public constant UNDERLYING_ASSET_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC - placeholder, verify with actual vault

    IDepositVault public issuanceVault;
    IRedemptionVault public redemptionVault;
    IMidasOracle public oracle;
    IERC20Metadata public underlyingAsset;

    uint256 forkBlock = 24011683;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(
                UNDERLYING_ASSET_ADDRESS,
                "Test Midas Fleet"
            );
        commander = _commander;
        bufferArk = _bufferArk;
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        underlyingAsset = IERC20Metadata(UNDERLYING_ASSET_ADDRESS);
        issuanceVault = IDepositVault(MIDAS_ISSUANCE_VAULT_ADDRESS);
        redemptionVault = IRedemptionVault(MIDAS_REDEMPTION_VAULT_ADDRESS);

        // TODO: Get withdrawal manager address from Midas protocol
        // This needs to be determined based on Midas architecture
        // Using a placeholder address that won't cause constructor revert
        // This will need to be replaced with actual Midas withdrawal manager address

        ArkParams memory params = ArkParams({
            name: "TestMidasArk",
            details: "TestMidasArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(underlyingAsset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new MidasArk(
            MIDAS_VAULT_ADDRESS,
            MIDAS_ISSUANCE_VAULT_ADDRESS,
            MIDAS_REDEMPTION_VAULT_ADDRESS,
            params
        );
        oracle = ark.oracle();
        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantCuratorRole(
            address(address(commander)),
            address(curator)
        );
        IFleetCommanderConfigProvider(commander).addArk(address(ark));
        vm.stopPrank();

        vm.startPrank(curator);
        ark.whitelistRouter(ODOS_ROUTER_MAINNET, true);
        vm.stopPrank();

        // Make addresses persistent for fork testing
        vm.makePersistent(address(underlyingAsset));
        vm.makePersistent(MIDAS_ISSUANCE_VAULT_ADDRESS);
        vm.makePersistent(MIDAS_REDEMPTION_VAULT_ADDRESS);
        vm.makePersistent(MIDAS_VAULT_ADDRESS);

        vm.label(commander, "Commander");
        vm.label(address(accessManager), "AccessManager");
        vm.label(address(configurationManager), "ConfigurationManager");
        vm.label(address(underlyingAsset), "UnderlyingAsset");
        vm.label(MIDAS_ISSUANCE_VAULT_ADDRESS, "IssuanceVault");
        vm.label(MIDAS_REDEMPTION_VAULT_ADDRESS, "RedemptionVault");
        vm.label(address(ark), "MidasArk");
    }

    function test_Board_Midas_fork() public {
        // Arrange
        uint256 amount = 500000 * 10 ** 6; // 500000 USDC (assuming 6 decimals)
        deal(address(underlyingAsset), commander, amount);

        vm.prank(commander);
        underlyingAsset.forceApprove(address(ark), amount);

        uint256 price = oracle.getDataInBase18();
        uint256 amountScaledTo18Decimals = amount * ark.TO_M_TOKEN_DECIMALS();
        uint256 minReceiveAmountIn18Decimals = (amountScaledTo18Decimals *
            Constants.WAD) / price;

        // Expect deposit call to issuance vault
        vm.expectCall(
            MIDAS_ISSUANCE_VAULT_ADDRESS,
            abi.encodeWithSignature(
                "depositInstant(address,uint256,uint256,bytes32)",
                address(underlyingAsset),
                amountScaledTo18Decimals,
                minReceiveAmountIn18Decimals,
                bytes32(0)
            )
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(underlyingAsset), amount);

        // Act
        vm.prank(commander);
        ark.board(amount, bytes(""));

        // Assert - verify assets increased
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertGt(
            assetsAfterDeposit,
            0,
            "Total assets should be greater than 0 after deposit"
        );

        // TODO: Test accrual over time if Midas vault accrues yield
        // vm.warp(block.timestamp + 10000);
        // uint256 assetsAfterAccrual = ark.totalAssets();
        // assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }

    function test_WithdrawUsingSwap_Midas() public {
        // First board some assets
        test_Board_Midas_fork();

        // Whitelist the redemption vault as a router
        vm.startPrank(curator);
        ark.whitelistRouter(address(redemptionVault), true);
        vm.stopPrank();

        // Calculate the amount to withdraw
        uint256 amount = 100 * 10 ** 6; // 100 USDC

        // Get oracle price to calculate shares (same calculation as withdrawUsingSwap)
        uint256 price = oracle.getDataInBase18();
        uint256 shares = (amount * ark.TO_M_TOKEN_DECIMALS() * Constants.WAD) /
            price;
        console.log("shares should be", shares);
        // Calculate minimum receive amount in 18 decimals (with slippage applied)
        // withdrawUsingSwap uses _applySlippage(amount) where amount is in asset decimals
        // But redeemInstant expects minReceiveAmount in 18 decimals
        uint256 amountIn18Decimals = (amount) * ark.TO_M_TOKEN_DECIMALS();

        // Apply slippage similar to _applySlippage
        uint256 fee = redemptionVault.instantFee(); // 0.5%
        uint256 minReceiveAmount = (amountIn18Decimals *
            (ark.ONE_HUNDRED_PERCENT() - fee)) / ark.ONE_HUNDRED_PERCENT();
        // round down and pad to asset decimals
        minReceiveAmount =
            minReceiveAmount /
            10 ** (18 - underlyingAsset.decimals());
        minReceiveAmount =
            minReceiveAmount *
            10 ** (underlyingAsset.decimals());

        // Encode calldata for redeemInstant(address tokenOut, uint256 amountMTokenIn, uint256 minReceiveAmount)
        bytes memory swapCalldata = abi.encodeWithSelector(
            IRedemptionVault.redeemInstant.selector,
            address(underlyingAsset),
            shares,
            minReceiveAmount
        );

        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: address(redemptionVault),
                swapCalldata: swapCalldata
            });
        bytes memory data = abi.encode(swapData);

        // Get balances before
        uint256 bufferArkBalanceBefore = underlyingAsset.balanceOf(bufferArk);
        uint256 arkBalanceBefore = underlyingAsset.balanceOf(address(ark));

        vm.startPrank(keeper);
        ark.withdrawUsingSwap(amount, data);
        vm.stopPrank();

        // Verify assets were transferred to buffer ark
        uint256 bufferArkBalanceAfter = underlyingAsset.balanceOf(bufferArk);
        assertGt(
            bufferArkBalanceAfter,
            bufferArkBalanceBefore,
            "Buffer ark should receive assets"
        );

        // Verify ark balance is back to 0 (assets were boarded to buffer ark)
        uint256 arkBalanceAfter = underlyingAsset.balanceOf(address(ark));
        assertEq(
            arkBalanceAfter,
            arkBalanceBefore,
            "Ark should not hold assets after withdrawUsingSwap"
        );
    }

    function test_RequestPartialRedeem_Midas_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request
        uint256 redeemAmount = 100 * 10 ** 6; // 100 USDC worth of shares

        // TODO: Use oracle to convert assets to shares
        // uint256 sharesAmount = oracle.convertAssetsToShares(
        //     MIDAS_REDEMPTION_VAULT_ADDRESS,
        //     redeemAmount
        // );

        // Expect redemption vault requestRedeem call
        // vm.expectCall(
        //     MIDAS_REDEMPTION_VAULT_ADDRESS,
        //     abi.encodeWithSelector(
        //         IRedemptionVault.requestRedeem.selector,
        //         sharesAmount,
        //         address(ark)
        //     )
        // );

        uint256 totalAssetsBefore = ark.totalAssets();
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);
        uint256 totalAssetsAfter = ark.totalAssets();

        // Allow for some rounding error
        assertApproxEqAbs(totalAssetsAfter, totalAssetsBefore, 1);

        // Verify we're waiting for withdrawal
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), redeemAmount, 1);
    }

    function test_RequestFullRedeem_Midas_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request with max uint
        vm.prank(keeper);
        ark.requestWithdrawal(type(uint256).max);

        // Verify we're waiting for withdrawal
        // TODO: Verify exact amount based on oracle conversion
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);
    }

    function test_WithdrawableTotalAssets_Midas_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Initially, withdrawable assets should be 0 since everything is in the vault
        assertEq(
            ark.withdrawableTotalAssets(),
            0,
            "Pre redeem request, withdrawable assets should be 0"
        );
        assertApproxEqAbs(
            ark.totalAssets(),
            amount,
            1,
            "Pre redeem request, total assets should be the same as the initial amount"
        );
        assertEq(
            ark.isWithdrawalClaimRequired(),
            false,
            "Withdrawal claim should not be required"
        );

        // Request withdrawal of half the assets
        uint256 redeemAmount = 500 * 10 ** 6; // 500 USDC
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);

        assertEq(
            ark.isWithdrawalClaimRequired(),
            false,
            "Withdrawal claim should not be required"
        );

        // Withdrawable assets should still be 0 since the withdrawal is still in queue
        assertEq(
            ark.withdrawableTotalAssets(),
            0,
            "Post redeem request, withdrawable assets should still be 0"
        );
        assertApproxEqAbs(
            ark.assetsInWithdrawalQueue(),
            redeemAmount,
            1,
            "Post redeem request, assets in withdrawal queue should be the same as the redeem amount"
        );
        assertApproxEqAbs(
            ark.totalAssets(),
            amount,
            2,
            "Post redeem request, total assets should be the same as the initial amount"
        );

        // TODO: Process withdrawals through Midas withdrawal manager
        // This will need to be implemented based on Midas withdrawal flow
        // vm.startPrank(MIDAS_REDEEMER_ADDRESS);
        // withdrawalManager.processRedemptions(redeemAmount);
        // vm.stopPrank();

        // TODO: After processing, verify withdrawable assets
        // assertApproxEqAbs(
        //     ark.withdrawableTotalAssets(),
        //     redeemAmount,
        //     1,
        //     "Withdrawable assets should match the processed withdrawal amount"
        // );
    }

    function test_WithdrawableTotalAssets_Midas_maxuint_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(underlyingAsset), commander, amount);
        // TODO: May need to deal assets to vaults for proper testing
        // deal(address(underlyingAsset), MIDAS_REDEMPTION_VAULT_ADDRESS, amount * 100);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Initially, withdrawable assets should be 0 since everything is in the vault
        assertEq(
            ark.withdrawableTotalAssets(),
            0,
            "Pre redeem request, withdrawable assets should be 0"
        );
        assertApproxEqAbs(
            ark.totalAssets(),
            amount,
            1,
            "Pre redeem request, total assets should be the same as the initial amount"
        );

        // Request withdrawal of all assets
        vm.prank(keeper);
        ark.requestWithdrawal(type(uint256).max);

        // Withdrawable assets should still be 0 since the withdrawal is still in queue
        assertEq(
            ark.withdrawableTotalAssets(),
            0,
            "Post redeem request, withdrawable assets should still be 0"
        );
        assertApproxEqAbs(
            ark.assetsInWithdrawalQueue(),
            amount,
            1,
            "Post redeem request, assets in withdrawal queue should be the same as the redeem amount"
        );

        // TODO: Process withdrawals through Midas withdrawal manager
        // vm.startPrank(MIDAS_REDEEMER_ADDRESS);
        // withdrawalManager.processRedemptions(amount);
        // vm.stopPrank();

        // TODO: Verify withdrawable assets after processing
        // assertApproxEqAbs(
        //     ark.withdrawableTotalAssets(),
        //     amount,
        //     1,
        //     "Withdrawable assets should match the processed withdrawal amount"
        // );
    }

    function test_WithdrawUsingSwap_NonWhitelistedRouter() public {
        test_Board_Midas_fork();
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: address(0x123), // Non-whitelisted router
                swapCalldata: hex"" // TODO: Generate swap calldata
            });
        bytes memory data = abi.encode(swapData);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("RouterNotWhitelisted()"));
        ark.withdrawUsingSwap(500000 * 10 ** 6, data);
    }

    function test_RequestWithdrawal_MaxUint() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // TODO: Verify shares are held (need to check which vault holds shares)
        // This depends on whether issuance and redemption vaults use the same share token
        // assertGt(
        //     IERC20(MIDAS_REDEMPTION_VAULT_ADDRESS).balanceOf(address(ark)),
        //     0,
        //     "There should be Midas shares in the ark"
        // );

        // Now test redeem request with max uint
        vm.prank(keeper);
        ark.requestWithdrawal(type(uint256).max);

        // Verify we're waiting for withdrawal of the full amount
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);

        // TODO: Verify shares are consumed (if redemption vault uses share token)
        // assertEq(
        //     IERC20(MIDAS_REDEMPTION_VAULT_ADDRESS).balanceOf(address(ark)),
        //     0,
        //     "There should be no Midas shares in the ark"
        // );
    }

    function test_TotalAssets_UsesOracle() public {
        // TODO: Test that totalAssets() correctly uses oracle for share price conversion
        // This is a key difference from SyrupArk which uses vault.convertToAssets()
        uint256 amount = 1000 * 10 ** 6;
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Verify totalAssets uses oracle
        uint256 totalAssets = ark.totalAssets();
        assertGt(totalAssets, 0, "Total assets should be greater than 0");

        // TODO: Verify oracle was called
        // This may require mocking the oracle or checking call logs
    }

    function test_AssetsInWithdrawalQueue_UsesOracle() public {
        // TODO: Test that assetsInWithdrawalQueue() uses oracle for conversion
        uint256 amount = 1000 * 10 ** 6;
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 redeemAmount = 500 * 10 ** 6;
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);

        // Verify assetsInWithdrawalQueue uses oracle conversion
        uint256 assetsInQueue = ark.assetsInWithdrawalQueue();
        assertApproxEqAbs(assetsInQueue, redeemAmount, 1);

        // TODO: Verify oracle was called for conversion
    }
}
