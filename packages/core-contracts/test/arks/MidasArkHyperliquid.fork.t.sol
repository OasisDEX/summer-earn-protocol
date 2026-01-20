// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/HyperBeatCoreArk.sol";
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
import {IHyperBeatDepositor} from "../../src/interfaces/hyperbeatcore/IHyperBeatDepositor.sol";
import {IHyperBeatWithdrawalQueue} from "../../src/interfaces/hyperbeatcore/IHyperBeatWithdrawalQueue.sol";
import {IHyperBeatPricer} from "../../src/interfaces/hyperbeatcore/IHyperBeatPricer.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract HyperBeatCoreArkHyperliquidTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;
    HyperBeatCoreArk public ark;
    address public bufferArk;

    // HyperBeatCore addresses for Hyperliquid
    address public constant HYPERBEAT_VAULT_TOKEN_ADDRESS =
        0x057ced81348D57Aad579A672d521d7b4396E8a61; // Vault token for Hyperbeat_USDC
    address public constant HYPERBEAT_DEPOSITOR_ADDRESS =
        0x929df52b0C3315D03922E12e54B46157395bE4D0;
    address public constant HYPERBEAT_WITHDRAWAL_QUEUE_ADDRESS =
        0x10024239474120CE410DD7ce203793c81d438Be3;

    // Hyperliquid USDC address
    address public constant UNDERLYING_ASSET_ADDRESS =
        0xb88339CB7199b77E23DB6E890353E22632Ba630f;

    IHyperBeatDepositor public depositor;
    IHyperBeatWithdrawalQueue public withdrawalQueue;
    IHyperBeatPricer public pricer;
    IERC20Metadata public underlyingAsset;

    uint256 forkBlock = 25012000;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(
                UNDERLYING_ASSET_ADDRESS,
                "Test HyperBeatCore Fleet Hyperliquid"
            );
        commander = _commander;
        bufferArk = _bufferArk;
        forkId = vm.createSelectFork(vm.rpcUrl("hyperliquid"), forkBlock);

        underlyingAsset = IERC20Metadata(UNDERLYING_ASSET_ADDRESS);
        depositor = IHyperBeatDepositor(HYPERBEAT_DEPOSITOR_ADDRESS);
        withdrawalQueue = IHyperBeatWithdrawalQueue(
            HYPERBEAT_WITHDRAWAL_QUEUE_ADDRESS
        );

        ArkParams memory params = ArkParams({
            name: "TestHyperBeatCoreArkHyperliquid",
            details: "TestHyperBeatCoreArk Hyperliquid details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(underlyingAsset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new HyperBeatCoreArk(
            HYPERBEAT_DEPOSITOR_ADDRESS,
            HYPERBEAT_WITHDRAWAL_QUEUE_ADDRESS,
            params
        );
        pricer = IHyperBeatPricer(ark.oracle());
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
        vm.makePersistent(HYPERBEAT_DEPOSITOR_ADDRESS);
        vm.makePersistent(HYPERBEAT_WITHDRAWAL_QUEUE_ADDRESS);
        vm.makePersistent(HYPERBEAT_VAULT_TOKEN_ADDRESS);

        vm.label(commander, "Commander");
        vm.label(address(accessManager), "AccessManager");
        vm.label(address(configurationManager), "ConfigurationManager");
        vm.label(address(underlyingAsset), "UnderlyingAsset");
        vm.label(HYPERBEAT_DEPOSITOR_ADDRESS, "Depositor");
        vm.label(HYPERBEAT_WITHDRAWAL_QUEUE_ADDRESS, "WithdrawalQueue");
        vm.label(address(ark), "HyperBeatCoreArk");
    }

    function test_Board_HyperBeatCore_fork() public {
        // Arrange
        uint256 amount = 500000 * 10 ** 6; // 500000 USDC (assuming 6 decimals)
        deal(address(underlyingAsset), commander, amount);

        vm.prank(commander);
        underlyingAsset.forceApprove(address(ark), amount);

        // Expect deposit call to depositor
        vm.expectCall(
            HYPERBEAT_DEPOSITOR_ADDRESS,
            abi.encodeWithSignature(
                "deposit(address,address,uint256,bytes32)",
                address(underlyingAsset),
                address(ark),
                amount,
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

        // TODO: Test accrual over time if HyperBeat vault accrues yield
        // vm.warp(block.timestamp + 10000);
        // uint256 assetsAfterAccrual = ark.totalAssets();
        // assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }

    function test_WithdrawUsingSwap_HyperBeatCore() public {
        // First board some assets
        test_Board_HyperBeatCore_fork();

        // Whitelist the withdrawal queue as a router
        vm.startPrank(curator);
        ark.whitelistRouter(address(withdrawalQueue), true);
        vm.stopPrank();

        // Calculate the amount to withdraw
        uint256 amount = 100 * 10 ** 6; // 100 USDC

        // Get shares using pricer (same calculation as withdrawUsingSwap)
        uint256 shares = pricer.getVaultTokenAmount(
            address(underlyingAsset),
            amount
        );

        // Encode calldata for instantWithdraw(address _user, uint256 _amount)
        bytes memory swapCalldata = abi.encodeWithSelector(
            IHyperBeatWithdrawalQueue.instantWithdraw.selector,
            address(ark),
            shares
        );

        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: address(withdrawalQueue),
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

    function test_RequestPartialRedeem_HyperBeatCore_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request
        uint256 redeemAmount = 100 * 10 ** 6; // 100 USDC worth of shares

        uint256 totalAssetsBefore = ark.totalAssets();
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);
        uint256 totalAssetsAfter = ark.totalAssets();

        // Allow for some rounding error
        assertApproxEqAbs(totalAssetsAfter, totalAssetsBefore, 1);

        // Verify we're waiting for withdrawal
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), redeemAmount, 1);
    }

    function test_RequestFullRedeem_HyperBeatCore_fork() public {
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
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);
    }

    function test_WithdrawableTotalAssets_HyperBeatCore_fork() public {
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
    }

    function test_WithdrawableTotalAssets_HyperBeatCore_maxuint_fork() public {
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
    }

    function test_WithdrawUsingSwap_NonWhitelistedRouter() public {
        test_Board_HyperBeatCore_fork();
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

        // Now test redeem request with max uint
        vm.prank(keeper);
        ark.requestWithdrawal(type(uint256).max);

        // Verify we're waiting for withdrawal of the full amount
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);
    }

    function test_TotalAssets_UsesPricer() public {
        uint256 amount = 1000 * 10 ** 6;
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Verify totalAssets uses pricer
        uint256 totalAssets = ark.totalAssets();
        assertGt(totalAssets, 0, "Total assets should be greater than 0");
    }

    function test_AssetsInWithdrawalQueue_UsesPricer() public {
        uint256 amount = 1000 * 10 ** 6;
        deal(address(underlyingAsset), commander, amount);

        vm.startPrank(commander);
        underlyingAsset.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 redeemAmount = 500 * 10 ** 6;
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);

        // Verify assetsInWithdrawalQueue uses pricer conversion
        uint256 assetsInQueue = ark.assetsInWithdrawalQueue();
        assertApproxEqAbs(assetsInQueue, redeemAmount, 1);
    }
}
