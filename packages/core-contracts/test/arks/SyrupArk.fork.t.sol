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
contract SyrupArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    SyrupArk public ark;
    SyrupArk public nextArk;

    address public constant syrupPoolAddress =
        0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b;
    address public constant usdcAddress =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant routerAddress =
        0x134cCaaA4F1e4552eC8aEcb9E4A2360dDcF8df76;
    ISyrupPool public syrupPool;
    IERC20 public usdc;

    uint256 forkBlock = 22274128; // Using the same block as Aave test for consistency
    uint256 forkId;

    // ark deposit autorization @ block 22274128
    ISyrupRouter.AuthData authData =
        ISyrupRouter.AuthData({
            bitmap: 16,
            deadline: 1744803326,
            auth_v: 28,
            auth_r: 0x24cf6b077bf7ba7544718ab03222808c5d46efe0838509c554fac69b35fd90a0,
            auth_s: 0x07eb14e29af792dcdca8609c7d95fc72784d96bff450795c9a578ccf1b74379a,
            depositData: 0x303a696e6a656374656400000000000000000000000000000000000000000000
        });
    bytes authDataBytes = abi.encode(authData);

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(usdcAddress);
        syrupPool = ISyrupPool(syrupPoolAddress);

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(usdc),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true,
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

        vm.label(commander, "Commander");
        vm.label(address(accessManager), "AccessManager");
        vm.label(address(configurationManager), "ConfigurationManager");
        vm.label(address(usdc), "USDC");
        vm.label(address(syrupPool), "SyrupPool");
        vm.label(address(ark), "Ark");
        vm.label(address(nextArk), "NextArk");
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
                ISyrupRouter.authorizeAndDeposit.selector,
                authData.bitmap,
                authData.deadline,
                authData.auth_v,
                authData.auth_r,
                authData.auth_s,
                amount,
                authData.depositData
            )
        );
        uint256 shares = ISyrupPool(syrupPoolAddress).convertToShares(amount);

        // Expect the Transfer event to be emitted - minted shares
        vm.expectEmit();
        emit IERC20.Transfer(routerAddress, address(ark), shares);

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount, authDataBytes);

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
        ark.board(amount, authDataBytes);
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
        ark.requestRedeem(redeemAmount);
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
        ark.board(amount, authDataBytes);
        vm.stopPrank();

        // Now test redeem request
        uint256 redeemAmount = type(uint256).max; // 1000 USDC worth of shares
        vm.prank(keeper);
        ark.requestRedeem(redeemAmount);

        // Verify we're waiting for withdrawal
        assertApproxEqAbs(ark.assetsInWithdrawalQueue(), amount, 1);
    }
}
