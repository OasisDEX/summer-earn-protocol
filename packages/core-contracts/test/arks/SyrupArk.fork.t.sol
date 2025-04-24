// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SyrupArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISyrupPool} from "../../src/interfaces/syrup/ISyrupPool.sol";
import {ISyrupRouter} from "../../src/interfaces/syrup/ISyrupRouter.sol";

// Mock interface for PoolPermissionManager
interface IPoolPermissionManager {
    function setLenderAllowlist(
        address poolManager_,
        address[] calldata lenders_,
        bool[] calldata booleans_
    ) external;
}

contract SyrupArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    SyrupArk public ark;
    SyrupArk public nextArk;
    IMapleWithdrawalManager public withdrawalManager;

    address public constant syrupPoolAddress =
        0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address public constant usdcAddress =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant routerAddress =
        0x134cCaaA4F1e4552eC8aEcb9E4A2360dDcF8df76;
    address public constant poolManagerAddress =
        0x7aD5fFa5fdF509E30186F4609c2f6269f4B6158F;
    address public constant poolPermissionManagerAddress =
        0xBe10aDcE8B6E3E02Db384E7FaDA5395DD113D8b3;
    address public constant syrupAdminAddress =
        0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;
    address public constant withdrawalManagerAddress =
        0x1bc47a0Dd0FdaB96E9eF982fdf1F34DC6207cfE3;
    address public constant syrup_redeemer =
        0x074a98D830eD61f39732FFa258e407f5cA7a8AaF;

    ISyrupPool public syrupPool;
    IERC20 public usdc;

    uint256 forkBlock = 22274128; // Using the same block as Aave test for consistency
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(usdcAddress);
        syrupPool = ISyrupPool(syrupPoolAddress);
        withdrawalManager = IMapleWithdrawalManager(withdrawalManagerAddress);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new SyrupArk(address(syrupPool), routerAddress, params);
        nextArk = new SyrupArk(address(syrupPool), routerAddress, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantCommanderRole(
            address(address(nextArk)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        nextArk.registerFleetCommander();
        vm.stopPrank();

        vm.startPrank(syrupAdminAddress);
        address[] memory lenders = new address[](1);
        lenders[0] = address(ark);
        bool[] memory booleans = new bool[](1);
        booleans[0] = true;
        IPoolPermissionManager(poolPermissionManagerAddress).setLenderAllowlist(
            poolManagerAddress,
            lenders,
            booleans
        );
        vm.stopPrank();

        vm.label(commander, "Commander");
        vm.label(address(accessManager), "AccessManager");
        vm.label(address(configurationManager), "ConfigurationManager");
        vm.label(address(usdc), "USDC");
        vm.label(address(syrupPool), "SyrupPool");
        vm.label(address(ark), "Ark");
        vm.label(address(nextArk), "NextArk");
        vm.label(poolManagerAddress, "PoolManager");
        vm.label(poolPermissionManagerAddress, "PoolPermissionManager");
        vm.label(withdrawalManagerAddress, "WithdrawalManager");
    }

    function test_Board_Syrup_fork() public {
        // Arrange
        uint256 amount = 5 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.prank(commander);
        usdc.forceApprove(address(ark), amount);

        vm.expectCall(
            address(routerAddress),
            abi.encodeWithSelector(
                ISyrupRouter.deposit.selector,
                amount,
                bytes32("summer")
            )
        );
        uint256 shares = ISyrupPool(syrupPoolAddress).convertToShares(amount);

        // Expect the Transfer event to be emitted - minted shares
        vm.expectEmit();
        emit IERC20.Transfer(routerAddress, address(ark), shares);

        // Expect the DepositData event to be emitted with summer referral code
        vm.expectEmit();
        emit ISyrupRouter.DepositData(address(ark), amount, bytes32("summer"));

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount, bytes(""));

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }

    function test_RequestPartialRedeem_Syrup_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request
        uint256 redeemAmount = 100 * 10 ** 6; // 500 USDC worth of shares
        uint256 sharesAmount = ISyrupPool(syrupPoolAddress).convertToShares(
            redeemAmount
        );
        vm.expectCall(
            address(syrupPool),
            abi.encodeWithSelector(
                syrupPool.requestRedeem.selector,
                sharesAmount,
                address(ark)
            )
        );
        uint256 totalAssetsBefore = ark.totalAssets();
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);
        uint256 totalAssetsAfter = ark.totalAssets();

        // Allow for some rounding error
        assertApproxEqAbs(totalAssetsAfter, totalAssetsBefore, 1);

        // Verify we're waiting for withdrawal
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), redeemAmount, 1);
    }

    function test_RequestFullRedeem_Syrup_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request
        uint256 redeemAmount = type(uint256).max; // 1000 USDC worth of shares
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);

        // Verify we're waiting for withdrawal
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);
    }

    function test_WithdrawableTotalAssets_Syrup_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
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

        // Request withdrawal of half the assets
        uint256 redeemAmount = 500 * 10 ** 6; // 500 USDC
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);

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
        deal(
            address(usdc),
            address(address(withdrawalManager)),
            redeemAmount * 1000
        );

        // process withdrawals
        vm.startPrank(syrup_redeemer);
        withdrawalManager.processRedemptions(redeemAmount * 1000);
        withdrawalManager.processRedemptions(redeemAmount * 1000);
        vm.stopPrank();

        // Now withdrawable assets should match the processed withdrawal amount
        assertApproxEqAbs(
            ark.withdrawableTotalAssets(),
            redeemAmount,
            1,
            "Withdrawable assets should match the processed withdrawal amount"
        );
        assertApproxEqAbs(
            ark.assetsInWithdrawalQueue(),
            0,
            1,
            "Assets in withdrawal queue should be 0"
        );
        assertApproxEqAbs(
            ark.totalAssets(),
            amount,
            2,
            "Total assets should be the initial amount"
        );
    }
}
interface IMapleWithdrawalManager {
    function processRedemptions(uint256 maxShares) external;
}
