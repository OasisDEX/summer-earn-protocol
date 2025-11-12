// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SyrupArk.sol";
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
    IMapleWithdrawalManager public withdrawalManager;
    address public bufferArk;
    address public constant SYRUP_USDC_POOL_ADDRESS =
        0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant SYRUP_USDC_ROUTER_ADDRESS =
        0x134cCaaA4F1e4552eC8aEcb9E4A2360dDcF8df76;
    address public constant SYRUP_USDC_POOL_MANAGER_ADDRESS =
        0x7aD5fFa5fdF509E30186F4609c2f6269f4B6158F;
    address public constant SYRUP_POOL_PERMISSION_MANAGER =
        0xBe10aDcE8B6E3E02Db384E7FaDA5395DD113D8b3;
    address public constant SYRUP_USDC_WITHDRAWAL_MANAGER_ADDRESS =
        0x1bc47a0Dd0FdaB96E9eF982fdf1F34DC6207cfE3;
    address public constant SYRUP_REDEEMER =
        0x074a98D830eD61f39732FFa258e407f5cA7a8AaF;
    address public constant SYRUP_ADMIN_ADDRESS =
        0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;

    ISyrupPool public syrupPool;
    IERC20 public usdc;

    uint256 forkBlock = 22445541; // Using the same block as Aave test for consistency
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(USDC_ADDRESS, "Test Fleet");
        commander = _commander;
        bufferArk = _bufferArk;
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        syrupPool = ISyrupPool(SYRUP_USDC_POOL_ADDRESS);
        withdrawalManager = IMapleWithdrawalManager(
            SYRUP_USDC_WITHDRAWAL_MANAGER_ADDRESS
        );

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

        ark = new SyrupArk(
            address(syrupPool),
            SYRUP_USDC_ROUTER_ADDRESS,
            params
        );

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

        vm.startPrank(SYRUP_ADMIN_ADDRESS);
        address[] memory lenders = new address[](1);
        lenders[0] = address(ark);
        bool[] memory booleans = new bool[](1);
        booleans[0] = true;
        IPoolPermissionManager(SYRUP_POOL_PERMISSION_MANAGER)
            .setLenderAllowlist(
                SYRUP_USDC_POOL_MANAGER_ADDRESS,
                lenders,
                booleans
            );
        vm.stopPrank();

        vm.makePersistent(address(usdc));
        vm.makePersistent(address(syrupPool));
        vm.makePersistent(address(SYRUP_USDC_ROUTER_ADDRESS));
        vm.makePersistent(address(SYRUP_USDC_POOL_ADDRESS));
        vm.makePersistent(address(SYRUP_USDC_WITHDRAWAL_MANAGER_ADDRESS));
        vm.makePersistent(address(SYRUP_REDEEMER));
        vm.makePersistent(address(SYRUP_ADMIN_ADDRESS));

        vm.label(commander, "Commander");
        vm.label(address(accessManager), "AccessManager");
        vm.label(address(configurationManager), "ConfigurationManager");
        vm.label(address(usdc), "USDC");
        vm.label(address(syrupPool), "SyrupPool");
        vm.label(address(ark), "Ark");
        vm.label(SYRUP_USDC_POOL_MANAGER_ADDRESS, "PoolManager");
        vm.label(SYRUP_POOL_PERMISSION_MANAGER, "PoolPermissionManager");
        vm.label(SYRUP_USDC_WITHDRAWAL_MANAGER_ADDRESS, "WithdrawalManager");
    }

    function test_Board_Syrup_fork() public {
        // Arrange
        uint256 amount = 500000 * 10 ** 6; // 500000 USDC
        deal(address(usdc), commander, amount);

        vm.prank(commander);
        usdc.forceApprove(address(ark), amount);

        vm.expectCall(
            address(SYRUP_USDC_ROUTER_ADDRESS),
            abi.encodeWithSelector(
                ISyrupRouter.deposit.selector,
                amount,
                bytes32("summer")
            )
        );
        uint256 shares = ISyrupPool(SYRUP_USDC_POOL_ADDRESS).convertToShares(
            amount
        );

        // Expect the Transfer event to be emitted - minted shares
        vm.expectEmit();
        emit IERC20.Transfer(SYRUP_USDC_ROUTER_ADDRESS, address(ark), shares);

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

    function test_WithdrawUsingSwap_Syrup() public {
        test_Board_Syrup_fork();
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: ODOS_ROUTER_MAINNET,
                swapCalldata: hex"83bd37f9000180ac24aa929eaf5013f6436cda2a7ba190f5cc0b0001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480569e9e421000574457d4f8d004189000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE9900000001A4AD4f68d0b91CFD19687c881e50f3A00242828c1f1508ef04020204012fb5d42107010101020195538979e579d49999f780c04fc4bf68778b6f0000000000000000000006d9000d0101030101ff000000000000000000000080ac24aa929eaf5013f6436cda2a7ba190f5cc0ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb48ab22d1d671bb5cee8735c5ba29ea651ccda48a8e00000000"
            });
        bytes memory data = abi.encode(swapData);
        vm.startPrank(keeper);
        ark.withdrawUsingSwap(500000 * 10 ** 6, data);
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
        uint256 sharesAmount = ISyrupPool(SYRUP_USDC_POOL_ADDRESS)
            .convertToShares(redeemAmount);
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

        // process withdrawals
        vm.startPrank(SYRUP_REDEEMER);
        withdrawalManager.processRedemptions(redeemAmount);
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

        uint256 bufferArkUsdcBalanceBefore = IERC20(USDC_ADDRESS).balanceOf(
            bufferArk
        );
        vm.expectEmit(true, true, true, true);
        emit Disembarked(address(keeper), USDC_ADDRESS, redeemAmount - 1);

        vm.prank(keeper);
        ark.sweep();

        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(bufferArk),
            bufferArkUsdcBalanceBefore + redeemAmount - 1
        );
    }
    function test_WithdrawableTotalAssets_Syrup_maxuint_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);
        deal(address(usdc), SYRUP_USDC_POOL_ADDRESS, amount * 100);

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
        uint256 redeemAmount = amount; // 1000 USDC
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
            redeemAmount,
            1,
            "Post redeem request, assets in withdrawal queue should be the same as the redeem amount"
        );

        // process withdrawals
        vm.startPrank(SYRUP_REDEEMER);
        withdrawalManager.processRedemptions(redeemAmount);
        vm.stopPrank();

        // Now withdrawable assets should match the processed withdrawal amount
        assertApproxEqAbs(
            ark.withdrawableTotalAssets(),
            redeemAmount,
            1,
            "Withdrawable assets should be greater than the processed withdrawal amount"
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
            1,
            "Total assets should be greater than the initial amount"
        );

        uint256 bufferArkUsdcBalanceBefore = IERC20(USDC_ADDRESS).balanceOf(
            bufferArk
        );

        vm.expectEmit(true, true, true, true);
        emit Disembarked(address(keeper), USDC_ADDRESS, amount - 1);

        vm.prank(keeper);
        ark.sweep();

        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(bufferArk),
            bufferArkUsdcBalanceBefore + amount - 1
        );
    }
    function test_WithdrawUsingSwap_NonWhitelistedRouter() public {
        test_Board_Syrup_fork();
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: address(0x123), // Non-whitelisted router
                swapCalldata: hex"83bd37f9000180ac24aa929eaf5013f6436cda2a7ba190f5cc0b0001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480569e9e421000574457d4f8d004189000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE9900000001A4AD4f68d0b91CFD19687c881e50f3A00242828c1f1508ef04020204012fb5d42107010101020195538979e579d49999f780c04fc4bf68778b6f0000000000000000000006d9000d0101030101ff000000000000000000000080ac24aa929eaf5013f6436cda2a7ba190f5cc0ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb48ab22d1d671bb5cee8735c5ba29ea651ccda48a8e00000000"
            });
        bytes memory data = abi.encode(swapData);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("RouterNotWhitelisted()"));
        ark.withdrawUsingSwap(500000 * 10 ** 6, data);
    }

    function test_RequestWithdrawal_MaxUint() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        assertGt(
            IERC20(address(syrupPool)).balanceOf(address(ark)),
            0,
            "There should be syrupUSDC in the ark"
        );
        // Now test redeem request with max uint
        vm.prank(keeper);
        ark.requestWithdrawal(type(uint256).max);

        // Verify we're waiting for withdrawal of the full amount
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);

        assertEq(
            IERC20(address(syrupPool)).balanceOf(address(ark)),
            0,
            "There should be no syrupUSDC in the ark"
        );
    }
}
interface IMapleWithdrawalManager {
    function processRedemptions(uint256 maxShares) external;
}
