// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/FluidLiteArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IEthVaultWrapperV2} from "../../src/interfaces/fluid/IEthVaultWrapperV2.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "../../src/interfaces/misc/IWETH.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract FluidLiteArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    FluidLiteArk public ark;
    IERC4626 public vault;
    IWETH public weth;
    ArkParams public params;

    // Router and vault addresses provided in the requirement
    address public constant ROUTER_ADDRESS =
        0x64338FD8e7b1918B4a806A175e26eD152B3d0b7b;
    address public constant VAULT_ADDRESS =
        0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78;

    // Using Ethereum Mainnet WETH
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant STETH_ADDRESS =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    uint256 forkBlock = 22324405; // Setting a fairly recent block number on Ethereum mainnet
    uint256 forkId;

    // Mock auth data for SyrupRouter
    IEthVaultWrapperV2.DepositData mockAuthData;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        weth = IWETH(WETH_ADDRESS);
        vault = IERC4626(VAULT_ADDRESS);

        params = ArkParams({
            name: "FluidLite ETH Ark",
            details: "FluidLite ETH Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: WETH_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true, // We require keeper data for signature authorization
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            params
        );

        // Set up mock auth data (this would typically be generated off-chain)
        mockAuthData = IEthVaultWrapperV2.DepositData({
            route: "1INCH-A",
            swapCalldata: abi.encodeWithSelector(
                IERC20.transfer.selector,
                address(ark),
                1 ether
            ),
            minStEthIn: 1 ether
        });

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        vm.label(WETH_ADDRESS, "WETH");
        vm.label(STETH_ADDRESS, "STETH");
        vm.label(ROUTER_ADDRESS, "ROUTER");
        vm.label(VAULT_ADDRESS, "VAULT");
        vm.label(address(ark), "ARK");
        vm.label(0x17144556fd3424EDC8Fc8A4C940B2D04936d17eb, "STETH_IMPL");
    }

    function test_Constructor() public {
        // Test with invalid router address
        vm.expectRevert(abi.encodeWithSignature("InvalidWrapperAddress()"));
        new FluidLiteArk(
            address(0),
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            params
        );

        // Test with invalid vault address
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new FluidLiteArk(
            ROUTER_ADDRESS,
            address(0),
            WETH_ADDRESS,
            STETH_ADDRESS,
            params
        );

        // Test with invalid WETH address
        vm.expectRevert(abi.encodeWithSignature("InvalidWETHAddress()"));
        new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            address(0),
            STETH_ADDRESS,
            params
        );

        // Test with non-WETH asset
        ArkParams memory badParams = params;
        badParams.asset = address(0x123); // Some random address that isn't WETH
        vm.expectRevert(abi.encodeWithSignature("AssetMustBeWETH()"));
        new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            badParams
        );

        // Valid constructor
        FluidLiteArk validArk = new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            params
        );

        assertEq(
            address(validArk.wrapper()),
            ROUTER_ADDRESS,
            "Wrapper address should match"
        );
        assertEq(
            address(validArk.vault()),
            VAULT_ADDRESS,
            "Vault address should match"
        );
        assertEq(
            address(validArk.weth()),
            WETH_ADDRESS,
            "WETH address should match"
        );
        assertEq(validArk.name(), "FluidLite ETH Ark", "Ark name should match");
    }

    function test_Board_FluidLite() public {
        uint256 amount = 1 ether; // 1 ETH

        // // Skip the actual router deposit since we can't easily mock the signature verification
        // // Instead, we'll use mocking to simulate successful deposit
        // vm.mockCall(
        //     ROUTER_ADDRESS,
        //     abi.encodeWithSelector(
        //         IEthVaultWrapperV2.deposit.selector,
        //         mockAuthData.route,
        //         mockAuthData.swapCalldata,
        //         mockAuthData.minStEthIn,
        //         address(ark)
        //     ),
        //     abi.encode(amount)
        // );

        // // Mock vault balanceOf to simulate successful deposit
        // vm.mockCall(
        //     VAULT_ADDRESS,
        //     abi.encodeWithSelector(IERC20.balanceOf.selector, address(ark)),
        //     abi.encode(amount)
        // );

        // // Mock vault convertToAssets to return the original amount
        // vm.mockCall(
        //     VAULT_ADDRESS,
        //     abi.encodeWithSelector(IERC4626.convertToAssets.selector, amount),
        //     abi.encode(amount)
        // );

        // Fund commander with WETH
        deal(WETH_ADDRESS, commander, amount);

        vm.startPrank(commander);
        IERC20(WETH_ADDRESS).approve(address(ark), amount);

        // Encode the auth data
        bytes memory boardData = abi.encode(mockAuthData);

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        ark.board(amount, boardData);
        vm.stopPrank();

        // Verify totalAssets returns the expected amount
        uint256 totalAssets = ark.totalAssets();
        assertApproxEqAbs(
            totalAssets,
            amount,
            1,
            "Total assets should match deposited amount"
        );
    }

    function test_Disembark() public {
        uint256 amount = 1 ether; // 1 ETH

        // Skip the actual router deposit and mocking for board operation
        vm.mockCall(
            ROUTER_ADDRESS,
            abi.encodeWithSelector(
                IEthVaultWrapperV2.deposit.selector,
                mockAuthData.route,
                mockAuthData.swapCalldata,
                mockAuthData.minStEthIn,
                address(ark)
            ),
            abi.encode(amount)
        );

        // Give the ark some WETH directly for testing disembark
        deal(WETH_ADDRESS, address(ark), amount);

        // Mock vault balanceOf to simulate successful deposit
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(ark)),
            abi.encode(amount)
        );

        // Mock vault convertToAssets to return the original amount
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC4626.convertToAssets.selector, amount),
            abi.encode(amount)
        );

        // Mock the maxWithdraw function
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC4626.maxWithdraw.selector, address(ark)),
            abi.encode(amount)
        );

        // Initial WETH balance of commander
        uint256 initialWETHBalance = IERC20(WETH_ADDRESS).balanceOf(commander);

        IEthVaultWrapperV2.WithdrawData memory withdrawData = IEthVaultWrapperV2
            .WithdrawData({
                route: "1INCH-A",
                amount: amount,
                swapCalldata: abi.encodeWithSelector(
                    IERC20.transfer.selector,
                    address(ark),
                    amount
                ),
                minEthOut: 0
            });

        vm.prank(commander);
        vm.expectEmit(true, true, true, true);
        emit Disembarked(commander, WETH_ADDRESS, amount);
        ark.disembark(amount, abi.encode(withdrawData));

        // Final WETH balance of commander
        uint256 finalWETHBalance = IERC20(WETH_ADDRESS).balanceOf(commander);
        assertEq(
            finalWETHBalance,
            initialWETHBalance + amount,
            "WETH balance should increase by disembarked amount"
        );
    }

    function test_DisembarkWithPartialVaultWithdrawal() public {
        uint256 amount = 1 ether; // 1 ETH
        uint256 arkWethBalance = 0.3 ether; // Ark has 0.3 ETH in WETH
        uint256 needFromVault = amount - arkWethBalance; // 0.7 ETH needed from vault

        // Give the ark some WETH directly
        deal(WETH_ADDRESS, address(ark), arkWethBalance);

        // Mock vault balanceOf to show ark has shares
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(ark)),
            abi.encode(needFromVault)
        );

        // Mock vault convertToAssets for share conversion
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.convertToAssets.selector,
                needFromVault
            ),
            abi.encode(needFromVault)
        );

        // Mock the maxWithdraw function
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC4626.maxWithdraw.selector, address(ark)),
            abi.encode(needFromVault)
        );

        // Mock previewWithdraw to return shares needed
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.previewWithdraw.selector,
                needFromVault
            ),
            abi.encode(needFromVault)
        );

        // Mock redeem function
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.redeem.selector,
                needFromVault,
                address(ark),
                address(ark)
            ),
            abi.encode(needFromVault)
        );

        // Send ETH to the ark to simulate vault withdrawal
        vm.deal(address(ark), needFromVault);

        // Initial WETH balance of commander
        uint256 initialWETHBalance = IERC20(WETH_ADDRESS).balanceOf(commander);
        IEthVaultWrapperV2.WithdrawData memory withdrawData = IEthVaultWrapperV2
            .WithdrawData({
                route: "1INCH-A",
                amount: amount,
                swapCalldata: abi.encodeWithSelector(
                    IERC20.transfer.selector,
                    address(ark),
                    amount
                ),
                minEthOut: 0
            });

        vm.prank(commander);
        ark.disembark(amount, abi.encode(withdrawData));

        // Final WETH balance of commander
        uint256 finalWETHBalance = IERC20(WETH_ADDRESS).balanceOf(commander);
        assertEq(
            finalWETHBalance,
            initialWETHBalance + amount,
            "WETH balance should increase by disembarked amount"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1 ether; // 1 ETH

        // Give the ark some WETH directly
        deal(WETH_ADDRESS, address(ark), 0.5 ether);

        // Mock vault balanceOf to simulate shares held
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(ark)),
            abi.encode(0.5 ether)
        );

        // Mock vault convertToAssets to return the value of shares
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.convertToAssets.selector,
                0.5 ether
            ),
            abi.encode(0.5 ether)
        );

        uint256 totalAssets = ark.totalAssets();
        assertEq(
            totalAssets,
            amount,
            "Total assets should be sum of direct WETH plus vault assets"
        );
    }

    function test_Harvest() public {
        // Mock vault balanceOf to simulate shares held
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(ark)),
            abi.encode(1 ether)
        );

        // Mock vault convertToAssets to return slightly more than initial value
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC4626.convertToAssets.selector, 1 ether),
            abi.encode(1.05 ether) // 5% yield
        );

        vm.prank(address(raft));
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest("");

        assertEq(
            rewardTokens.length,
            0,
            "No explicit reward tokens should be returned"
        );
        assertEq(
            rewardAmounts.length,
            0,
            "No explicit reward amounts should be returned"
        );

        uint256 totalAssets = ark.totalAssets();
        assertEq(
            totalAssets,
            1.05 ether,
            "Total assets should include auto-compounded yield"
        );
    }

    function test_ValidateBoardData() public {
        // Empty data should revert
        bytes memory emptyData = "";
        vm.expectRevert(abi.encodeWithSignature("KeeperDataRequired()"));

        vm.prank(commander);
        ark.board(1 ether, emptyData);

        // Valid auth data should work
        bytes memory validData = abi.encode(mockAuthData);

        // Mock the authorizeAndDeposit call
        vm.mockCall(
            ROUTER_ADDRESS,
            abi.encodeWithSelector(
                IEthVaultWrapperV2.deposit.selector,
                mockAuthData.route,
                mockAuthData.swapCalldata,
                mockAuthData.minStEthIn,
                address(ark)
            ),
            abi.encode(1 ether)
        );

        // Fund commander with WETH
        deal(WETH_ADDRESS, commander, 1 ether);

        vm.startPrank(commander);
        IERC20(WETH_ADDRESS).approve(address(ark), 1 ether);
        ark.board(1 ether, validData);
        vm.stopPrank();
    }
}
