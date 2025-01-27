// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuarters} from "../../src/contracts/AdmiralsQuarters.sol";

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {IAggregationRouterV6} from "../../src/interfaces/1inch/IAggregationRouterV6.sol";
import {IFleetCommanderRewardsManager} from "../../src/interfaces/IFleetCommanderRewardsManager.sol";

import {IComet} from "../../src/interfaces/compound-v3/IComet.sol";
import {FleetCommanderTestBase} from "../fleets/FleetCommanderTestBase.sol";
import {OneInchTestHelpers} from "../helpers/OneInchTestHelpers.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Test, console} from "forge-std/Test.sol";

contract AdmiralsQuartersImportTest is
    FleetCommanderTestBase,
    OneInchTestHelpers
{
    AdmiralsQuarters public admiralsQuarters;
    IAggregationRouterV6 public oneInchRouter;

    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant UNISWAP_USDC_DAI_V3_POOL =
        0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant CUSDC_ADDRESS =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant CUSDC_HOLDER =
        0x07f56A3a9868e38EAfe7C82A28b7dC51106D138A;
    address public constant AUSDC_ADDRESS =
        0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address public constant AUSDC_HOLDER =
        0xD0b00b41F3e1a8dbFf6aBA1c0B0d7e4984605010;
    address public constant USDC_4626_VAULT =
        0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address public constant USDC_4626_HOLDER =
        0x741AA7CFB2c7bF2A1E7D4dA2e3Df6a56cA4131F3;

    address public user1 = address(0x1111);
    address public user2 = address(0x2222);
    FleetCommander public usdcFleet;
    FleetCommander public daiFleet;

    uint256 constant FORK_BLOCK = 20576616;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        oneInchRouter = IAggregationRouterV6(ONE_INCH_ROUTER);
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithoutArks(USDC_ADDRESS, initialTipRate);
        usdcFleet = fleetCommander;
        console.log("usdcFleet", address(usdcFleet));
        console.log("bufferArk", address(bufferArk));
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(bufferArk)),
            address(fleetCommander)
        );
        vm.stopPrank();

        initializeFleetCommanderWithoutArks(DAI_ADDRESS, initialTipRate);
        daiFleet = fleetCommander;
        console.log("daiFleet", address(daiFleet));
        console.log("bufferArk", address(bufferArk));
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(bufferArk)),
            address(fleetCommander)
        );

        admiralsQuarters = new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager),
            WETH
        );

        // Grant roles
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            address(this)
        );
        vm.stopPrank();

        // Mint tokens for users
        deal(USDC_ADDRESS, user1, 1000e6);
        deal(USDC_ADDRESS, user2, 1000e6);

        // Approve AdmiralsQuarters to spend user tokens
        vm.startPrank(user1);
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        IERC20(DAI_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        IERC20(DAI_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();
        vm.label(address(daiFleet), "DAI Fleet");
        vm.label(address(usdcFleet), "USDC Fleet");

        vm.label(USDC_ADDRESS, "USDC");
        vm.label(DAI_ADDRESS, "DAI");
    }

    function test_ImportFromCompound() public {
        uint256 cTokenAmount = 50000e8; // cUSDC has 8 decimals

        user1 = CUSDC_HOLDER;
        uint256 balanceBefore = IERC20(CUSDC_ADDRESS).balanceOf(user1);
        vm.startPrank(user1);

        // Approve tokens and import position
        IComet(CUSDC_ADDRESS).allow(address(admiralsQuarters), true);

        bytes[] memory importCalls = new bytes[](3);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromCompoundToAdmiralsQuarters,
            (CUSDC_ADDRESS, cTokenAmount)
        );
        importCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), 0, address(admiralsQuarters))
        );
        importCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );

        admiralsQuarters.multicall(importCalls);

        // Verify results
        assertEq(
            IERC20(CUSDC_ADDRESS).balanceOf(user1),
            balanceBefore - cTokenAmount - 1,
            "Should have no cUSDC left"
        );
        assertGt(
            IFleetCommanderRewardsManager(
                usdcFleet.getConfig().stakingRewardsManager
            ).balanceOf(user1),
            0,
            "Should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportFromAave() public {
        uint256 aTokenAmount = 1000e6; // aUSDC has same decimals as USDC

        vm.startPrank(AUSDC_HOLDER);
        uint256 initialUserBalance = IERC20(AUSDC_ADDRESS).balanceOf(
            AUSDC_HOLDER
        );
        // Approve tokens and import position
        IERC20(AUSDC_ADDRESS).approve(address(admiralsQuarters), aTokenAmount);

        bytes[] memory importCalls = new bytes[](3);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromAaveToAdmiralsQuarters,
            (AUSDC_ADDRESS, aTokenAmount)
        );
        importCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), 0, address(admiralsQuarters))
        );
        importCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );

        admiralsQuarters.multicall(importCalls);

        // Verify results
        assertEq(
            IERC20(AUSDC_ADDRESS).balanceOf(AUSDC_HOLDER),
            initialUserBalance - aTokenAmount - 1,
            "Should have no aUSDC left"
        );
        assertGt(
            IFleetCommanderRewardsManager(
                usdcFleet.getConfig().stakingRewardsManager
            ).balanceOf(AUSDC_HOLDER),
            0,
            "Should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportFromERC4626() public {
        user1 = USDC_4626_HOLDER;
        uint256 sharesToRedeem = 1000e6; // Assuming same decimals as USDC

        uint256 sharesAmountBefore = IERC4626(USDC_4626_VAULT).balanceOf(user1);

        vm.startPrank(user1);

        // Approve tokens and import position
        IERC20(USDC_4626_VAULT).approve(
            address(admiralsQuarters),
            sharesToRedeem
        );

        bytes[] memory importCalls = new bytes[](3);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromERC4626ToAdmiralsQuarters,
            (USDC_4626_VAULT, sharesToRedeem)
        );
        importCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), 0, address(admiralsQuarters))
        );
        importCalls[2] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );

        admiralsQuarters.multicall(importCalls);

        // Verify results
        assertEq(
            IERC20(USDC_4626_VAULT).balanceOf(user1),
            sharesAmountBefore - sharesToRedeem,
            "Should have less shares left"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no USDC left"
        );
        assertEq(
            IERC20(USDC_4626_VAULT).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no USDC 4626 vault tokens left"
        );
        assertGt(
            IFleetCommanderRewardsManager(
                usdcFleet.getConfig().stakingRewardsManager
            ).balanceOf(user1),
            0,
            "Should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportAll_Multicall() public {
        // Deal tokens to user
        uint256 cTokenAmount = 50000e8;
        uint256 aTokenAmount = 1000e6;
        uint256 vaultSharesAmount = 1000e6;

        user1 = CUSDC_HOLDER;
        vm.prank(AUSDC_HOLDER);
        IERC20(AUSDC_ADDRESS).transfer(user1, aTokenAmount);
        vm.prank(USDC_4626_HOLDER);
        IERC20(USDC_4626_VAULT).transfer(user1, vaultSharesAmount);

        uint256 erc4626sharesBefore = IERC4626(USDC_4626_VAULT).balanceOf(
            user1
        );
        uint256 aTokenBefore = IERC20(AUSDC_ADDRESS).balanceOf(user1);
        uint256 cTokenBefore = IERC20(CUSDC_ADDRESS).balanceOf(user1);

        vm.startPrank(user1);

        // Approve all tokens
        IComet(CUSDC_ADDRESS).allow(address(admiralsQuarters), true);
        IERC20(AUSDC_ADDRESS).approve(address(admiralsQuarters), aTokenAmount);
        IERC20(USDC_4626_VAULT).approve(
            address(admiralsQuarters),
            vaultSharesAmount
        );

        // Import all positions in one multicall
        bytes[] memory importCalls = new bytes[](5);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromCompoundToAdmiralsQuarters,
            (CUSDC_ADDRESS, cTokenAmount)
        );
        importCalls[1] = abi.encodeCall(
            admiralsQuarters.moveFromAaveToAdmiralsQuarters,
            (AUSDC_ADDRESS, aTokenAmount)
        );
        importCalls[2] = abi.encodeCall(
            admiralsQuarters.moveFromERC4626ToAdmiralsQuarters,
            (USDC_4626_VAULT, vaultSharesAmount)
        );
        importCalls[3] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), 0, address(admiralsQuarters))
        );
        importCalls[4] = abi.encodeCall(
            admiralsQuarters.stake,
            (address(usdcFleet), 0)
        );

        admiralsQuarters.multicall(importCalls);

        // Verify results
        assertEq(
            IERC20(CUSDC_ADDRESS).balanceOf(user1),
            cTokenBefore - cTokenAmount - 1,
            "Should have less cUSDC left"
        );
        assertEq(
            IERC20(AUSDC_ADDRESS).balanceOf(user1),
            aTokenBefore - aTokenAmount - 1,
            "Should have less aUSDC left"
        );
        assertEq(
            IERC20(USDC_4626_VAULT).balanceOf(user1),
            erc4626sharesBefore - vaultSharesAmount,
            "Should have less shares left"
        );
        assertGt(
            IFleetCommanderRewardsManager(
                usdcFleet.getConfig().stakingRewardsManager
            ).balanceOf(user1),
            0,
            "Should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportZeroAmount() public {
        // Test importing with amount = 0 (should import full balance)
        user1 = CUSDC_HOLDER;
        vm.startPrank(user1);
        IComet(CUSDC_ADDRESS).allow(address(admiralsQuarters), true);

        bytes[] memory importCalls = new bytes[](2);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromCompoundToAdmiralsQuarters,
            (CUSDC_ADDRESS, 0)
        );
        importCalls[1] = abi.encodeCall(
            admiralsQuarters.enterFleet,
            (address(usdcFleet), 0, address(0))
        );
        admiralsQuarters.multicall(importCalls);

        assertEq(
            IERC20(CUSDC_ADDRESS).balanceOf(user1),
            0,
            "Should have imported all cUSDC"
        );
        assertGt(
            usdcFleet.balanceOf(user1),
            0,
            "Should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportReverts() public {
        vm.startPrank(user1);

        // Test invalid token addresses
        vm.expectRevert();
        admiralsQuarters.moveFromCompoundToAdmiralsQuarters(address(0), 1000);

        vm.expectRevert();
        admiralsQuarters.moveFromAaveToAdmiralsQuarters(address(0), 1000);

        vm.expectRevert();
        admiralsQuarters.moveFromERC4626ToAdmiralsQuarters(address(0), 1000);

        // Test insufficient balance
        vm.expectRevert();
        admiralsQuarters.moveFromCompoundToAdmiralsQuarters(
            CUSDC_ADDRESS,
            1000
        );

        vm.stopPrank();
    }
}
