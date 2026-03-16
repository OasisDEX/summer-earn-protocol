// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/MapleInstitutionalArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/events/IArkEvents.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {ISyrupPool} from "../../src/interfaces/syrup/ISyrupPool.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

// Mock interface for PoolPermissionManager
interface IPoolPermissionManager {
    function setLenderAllowlist(
        address poolManager_,
        address[] calldata lenders_,
        bool[] calldata booleans_
    ) external;
}

contract MapleInstitutionalArkUSDCTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    MapleInstitutionalArk public ark;
    IMapleWithdrawalManager public withdrawalManager;
    address public bufferArk;
    address public constant MAPLE_INSTITUTIONAL_USDC_POOL_ADDRESS =
        0xC39a5A616F0ad1Ff45077FA2dE3f79ab8eb8b8B9;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant MAPLE_INSTITUTIONAL_USDC_POOL_MANAGER_ADDRESS =
        0x9ceF7d1D390A4811bBa1BC40A53B40a506C33B19;
    address public constant MAPLE_POOL_PERMISSION_MANAGER =
        0xBe10aDcE8B6E3E02Db384E7FaDA5395DD113D8b3;
    address
        public constant MAPLE_INSTITUTIONAL_USDC_WITHDRAWAL_MANAGER_ADDRESS =
        0x8A665131e796203a5232527fac441480e02fbB7F;
    address public constant SYRUP_REDEEMER =
        0x074a98D830eD61f39732FFa258e407f5cA7a8AaF;
    address public constant SYRUP_ADMIN_ADDRESS =
        0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;

    ISyrupPool public syrupPool;
    IERC20 public usdc;

    uint256 forkBlock = 24519080;
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
        syrupPool = ISyrupPool(MAPLE_INSTITUTIONAL_USDC_POOL_ADDRESS);
        withdrawalManager = IMapleWithdrawalManager(
            MAPLE_INSTITUTIONAL_USDC_WITHDRAWAL_MANAGER_ADDRESS
        );

        ArkParams memory params = ArkParams({
            name: "MapleInstitutionalArk",
            details: "Maple Institutional Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new MapleInstitutionalArk(address(syrupPool), params);

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
        IPoolPermissionManager(MAPLE_POOL_PERMISSION_MANAGER)
            .setLenderAllowlist(
                MAPLE_INSTITUTIONAL_USDC_POOL_MANAGER_ADDRESS,
                lenders,
                booleans
            );
        vm.stopPrank();

        vm.makePersistent(address(usdc));
        vm.makePersistent(address(syrupPool));
        vm.makePersistent(address(MAPLE_INSTITUTIONAL_USDC_POOL_ADDRESS));
        vm.makePersistent(
            address(MAPLE_INSTITUTIONAL_USDC_WITHDRAWAL_MANAGER_ADDRESS)
        );
        vm.makePersistent(address(SYRUP_REDEEMER));
        vm.makePersistent(address(SYRUP_ADMIN_ADDRESS));

        vm.label(commander, "Commander");
        vm.label(address(accessManager), "AccessManager");
        vm.label(address(configurationManager), "ConfigurationManager");
        vm.label(address(usdc), "USDC");
        vm.label(address(syrupPool), "MaplePool");
        vm.label(address(ark), "Ark");
        vm.label(MAPLE_INSTITUTIONAL_USDC_POOL_MANAGER_ADDRESS, "PoolManager");
        vm.label(MAPLE_POOL_PERMISSION_MANAGER, "PoolPermissionManager");
        vm.label(
            MAPLE_INSTITUTIONAL_USDC_WITHDRAWAL_MANAGER_ADDRESS,
            "WithdrawalManager"
        );
    }

    function test_Board_MapleInstitutional_fork() public {
        // Arrange
        uint256 amount = 500000 * 10 ** 6; // 500000 USDC
        deal(address(usdc), commander, amount);

        vm.prank(commander);
        usdc.forceApprove(address(ark), amount);

        uint256 shares = syrupPool.convertToShares(amount);

        // Expect the Transfer event to be emitted - minted shares
        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(ark), shares);

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        // Act
        vm.prank(commander);
        ark.board(amount, bytes(""));

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }

    function test_RequestPartialRedeem_MapleInstitutional_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request
        uint256 withdrawalAmount = 100 * 10 ** 6;
        uint256 sharesAmount = syrupPool.convertToExitShares(withdrawalAmount);

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
        ark.requestWithdrawal(withdrawalAmount);
        uint256 totalAssetsAfter = ark.totalAssets();

        // Allow for some rounding error
        assertApproxEqAbs(totalAssetsAfter, totalAssetsBefore, 2);

        // Verify we're waiting for withdrawal
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), withdrawalAmount, 2);
    }

    function test_RequestFullRedeem_MapleInstitutional_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Now test redeem request
        uint256 withdrawalAmount = type(uint256).max;
        vm.prank(keeper);
        ark.requestWithdrawal(withdrawalAmount);

        // Verify we're waiting for withdrawal
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 2);
    }

    function test_WithdrawableTotalAssets_MapleInstitutional_fork() public {
        // First board some assets
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Initially, withdrawable assets should be 0
        assertEq(
            ark.withdrawableTotalAssets(),
            0,
            "Pre redeem request, withdrawable assets should be 0"
        );
        assertApproxEqAbs(
            ark.totalAssets(),
            amount,
            2,
            "Pre redeem request, total assets should be the same as the initial amount"
        );

        // Request withdrawal of half the assets
        uint256 withdrawalAmount = 500 * 10 ** 6;
        vm.prank(keeper);
        ark.requestWithdrawal(withdrawalAmount);

        // Withdrawable assets should still be 0
        assertEq(
            ark.withdrawableTotalAssets(),
            0,
            "Withdrawable assets should still be 0"
        );

        assertApproxEqAbs(
            ark.assetsInWithdrawalQueue(),
            withdrawalAmount,
            2,
            "Assets in withdrawal queue should match the withdrawal amount"
        );

        // process withdrawals
        vm.startPrank(SYRUP_REDEEMER);
        deal(
            address(usdc),
            address(MAPLE_INSTITUTIONAL_USDC_POOL_ADDRESS),
            withdrawalAmount * 4
        );
        withdrawalManager.processRedemptions(withdrawalAmount);
        vm.stopPrank();

        // Now withdrawable assets should match the processed withdrawal amount
        assertGt(
            ark.totalAssets(),
            amount,
            "Total assets should be greater than the initial amount"
        );
        assertGt(
            ark.withdrawableTotalAssets(),
            withdrawalAmount,
            "Withdrawable assets should be greater than the processed withdrawal amount"
        );

        assertApproxEqAbs(
            ark.assetsInWithdrawalQueue(),
            0,
            2,
            "Assets in withdrawal queue should be 0"
        );

        uint256 bufferArkUsdcBalanceBefore = IERC20(USDC_ADDRESS).balanceOf(
            bufferArk
        );

        vm.prank(keeper);
        ark.sweep();

        assertGt(
            IERC20(USDC_ADDRESS).balanceOf(bufferArk),
            bufferArkUsdcBalanceBefore + withdrawalAmount,
            "Buffer Ark USDC balance should be greater than the withdrawal amount"
        );
    }
}

interface IMapleWithdrawalManager {
    function processRedemptions(uint256 maxShares) external;
}
