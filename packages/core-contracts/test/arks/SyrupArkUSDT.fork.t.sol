// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SyrupArk.sol";
import {Test, console} from "forge-std/Test.sol";

import "../../src/events/IArkEvents.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
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

contract SyrupArkUSDTTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    SyrupArk public ark;
    IMapleWithdrawalManager public withdrawalManager;
    address public bufferArk;
    address public constant SYRUP_USDT_POOL_ADDRESS =
        0x356B8d89c1e1239Cbbb9dE4815c39A1474d5BA7D;
    address public constant USDT_ADDRESS =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant SYRUP_USDT_ROUTER_ADDRESS =
        0xF007476Bb27430795138C511F18F821e8D1e5Ee2;
    address public constant SYRUP_USDT_POOL_MANAGER_ADDRESS =
        0x0cdA32E08B48bFDDbc7eE96B44b09cf286F9E21a;
    address public constant SYRUP_POOL_PERMISSION_MANAGER =
        0xBe10aDcE8B6E3E02Db384E7FaDA5395DD113D8b3;
    address public constant SYRUP_USDT_WITHDRAWAL_MANAGER_ADDRESS =
        0x86eBDf902d800F2a82038290B6DBb2A5eE29eB8C;
    address public constant SYRUP_REDEEMER =
        0x074a98D830eD61f39732FFa258e407f5cA7a8AaF;
    address public constant SYRUP_ADMIN_ADDRESS =
        0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;

    ISyrupPool public syrupPool;
    IERC20 public usdt;

    uint256 forkBlock = 22487777; // Using the same block as Aave test for consistency
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(USDT_ADDRESS, "Test Fleet");
        commander = _commander;
        bufferArk = _bufferArk;
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdt = IERC20(USDT_ADDRESS);
        syrupPool = ISyrupPool(SYRUP_USDT_POOL_ADDRESS);
        withdrawalManager = IMapleWithdrawalManager(
            SYRUP_USDT_WITHDRAWAL_MANAGER_ADDRESS
        );

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdt),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new SyrupArk(
            address(syrupPool),
            SYRUP_USDT_ROUTER_ADDRESS,
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
        ark.whitelistRouter(KYBER_ROUTER_MAINNET, true);
        vm.stopPrank();

        vm.startPrank(SYRUP_ADMIN_ADDRESS);
        address[] memory lenders = new address[](1);
        lenders[0] = address(ark);
        bool[] memory booleans = new bool[](1);
        booleans[0] = true;
        IPoolPermissionManager(SYRUP_POOL_PERMISSION_MANAGER)
            .setLenderAllowlist(
                SYRUP_USDT_POOL_MANAGER_ADDRESS,
                lenders,
                booleans
            );
        vm.stopPrank();

        vm.makePersistent(address(usdt));
        vm.makePersistent(address(syrupPool));
        vm.makePersistent(address(SYRUP_USDT_ROUTER_ADDRESS));
        vm.makePersistent(address(SYRUP_USDT_POOL_ADDRESS));
        vm.makePersistent(address(SYRUP_USDT_WITHDRAWAL_MANAGER_ADDRESS));
        vm.makePersistent(address(SYRUP_REDEEMER));
        vm.makePersistent(address(SYRUP_ADMIN_ADDRESS));

        vm.label(commander, "Commander");
        vm.label(address(accessManager), "AccessManager");
        vm.label(address(configurationManager), "ConfigurationManager");
        vm.label(address(usdt), "USDT");
        vm.label(address(syrupPool), "SyrupPool");
        vm.label(address(ark), "Ark");
        vm.label(SYRUP_USDT_POOL_MANAGER_ADDRESS, "PoolManager");
        vm.label(SYRUP_POOL_PERMISSION_MANAGER, "PoolPermissionManager");
        vm.label(SYRUP_USDT_WITHDRAWAL_MANAGER_ADDRESS, "WithdrawalManager");
    }

    function test_Board_Syrup_fork() public {
        // Arrange
        uint256 amount = 10000 * 10 ** 6; // 10000 USDT
        deal(address(usdt), commander, amount);

        vm.prank(commander);
        usdt.forceApprove(address(ark), amount);

        vm.expectCall(
            address(SYRUP_USDT_ROUTER_ADDRESS),
            abi.encodeWithSelector(
                ISyrupRouter.deposit.selector,
                amount,
                bytes32("summer")
            )
        );
        uint256 shares = ISyrupPool(SYRUP_USDT_POOL_ADDRESS).convertToShares(
            amount
        );

        // Expect the Transfer event to be emitted - minted shares
        vm.expectEmit();
        emit IERC20.Transfer(SYRUP_USDT_ROUTER_ADDRESS, address(ark), shares);

        // Expect the DepositData event to be emitted with summer referral code
        vm.expectEmit();
        emit ISyrupRouter.DepositData(address(ark), amount, bytes32("summer"));

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(usdt), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount, bytes(""));

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }

    function test_WithdrawUsingSwap_Syrup() public {
        console.log("test_WithdrawUsingSwap_Syrup");
        console.log("no route with enough liquidity");
    }

    function test_RequestPartialRedeem_Syrup_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDT
        deal(address(usdt), commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request
        uint256 redeemAmount = 100 * 10 ** 6; // 100 USDT worth of shares
        uint256 sharesAmount = ISyrupPool(SYRUP_USDT_POOL_ADDRESS)
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
        uint256 amount = 1000 * 10 ** 6; // 1000 USDT
        deal(address(usdt), commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request
        uint256 redeemAmount = type(uint256).max; // 1000 USDT worth of shares
        vm.prank(keeper);
        ark.requestWithdrawal(redeemAmount);

        // Verify we're waiting for withdrawal
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);
    }

    function test_WithdrawableTotalAssets_Syrup_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDT
        deal(address(usdt), commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
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
        uint256 redeemAmount = 500 * 10 ** 6; // 500 USDT
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

        uint256 bufferArkUsdtBalanceBefore = IERC20(USDT_ADDRESS).balanceOf(
            bufferArk
        );
        vm.expectEmit(true, true, true, true);
        emit Disembarked(address(keeper), USDT_ADDRESS, redeemAmount - 1);

        vm.prank(keeper);
        ark.sweep();

        assertEq(
            IERC20(USDT_ADDRESS).balanceOf(bufferArk),
            bufferArkUsdtBalanceBefore + redeemAmount - 1
        );
    }

    function test_WithdrawableTotalAssets_Syrup_maxuint_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDT
        deal(address(usdt), commander, amount);
        deal(address(usdt), SYRUP_USDT_POOL_ADDRESS, amount * 100);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
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
        uint256 redeemAmount = amount; // 1000 USDT
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

        uint256 bufferArkUsdtBalanceBefore = IERC20(USDT_ADDRESS).balanceOf(
            bufferArk
        );

        vm.expectEmit(true, true, true, true);
        emit Disembarked(address(keeper), USDT_ADDRESS, amount - 1);

        vm.prank(keeper);
        ark.sweep();

        assertEq(
            IERC20(USDT_ADDRESS).balanceOf(bufferArk),
            bufferArkUsdtBalanceBefore + amount - 1
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
        ark.withdrawUsingSwap(10000 * 10 ** 6, data);
    }

    function test_RequestWithdrawal_MaxUint() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDT
        deal(address(usdt), commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        assertGt(
            IERC20(address(syrupPool)).balanceOf(address(ark)),
            0,
            "There should be syrupUSDT in the ark"
        );
        // Now test redeem request with max uint
        vm.prank(keeper);
        ark.requestWithdrawal(type(uint256).max);

        // Verify we're waiting for withdrawal of the full amount
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);

        assertEq(
            IERC20(address(syrupPool)).balanceOf(address(ark)),
            0,
            "There should be no syrupUSDT in the ark"
        );
    }
}

interface IMapleWithdrawalManager {
    function processRedemptions(uint256 maxShares) external;
}
