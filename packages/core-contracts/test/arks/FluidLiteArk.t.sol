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
    address public constant WITHDRAWAL_QUEUE_ADDRESS =
        0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;

    uint256 forkBlock = 22324405; // Setting a fairly recent block number on Ethereum mainnet
    uint256 forkId;

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
            requiresKeeperData: false, // We require keeper data for signature authorization
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
            params
        );

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
            WITHDRAWAL_QUEUE_ADDRESS,
            params
        );

        // Test with invalid vault address
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new FluidLiteArk(
            ROUTER_ADDRESS,
            address(0),
            WETH_ADDRESS,
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
            params
        );

        // Test with invalid WETH address
        vm.expectRevert(abi.encodeWithSignature("InvalidWETHAddress()"));
        new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            address(0),
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
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
            WITHDRAWAL_QUEUE_ADDRESS,
            badParams
        );

        // Valid constructor
        FluidLiteArk validArk = new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
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

        // Fund commander with WETH
        deal(WETH_ADDRESS, commander, amount);

        vm.startPrank(commander);
        IERC20(WETH_ADDRESS).approve(address(ark), amount);

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        ark.board(amount, bytes(""));
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
        console.log("not implemented");
    }
    function test_ReqestWithdrawaWithSwap() public {
        console.log("not implemented");
    }
    function test_ClaimWithdrawal() public {
        console.log("not implemented");
    }

    function test_RequestWithdrawal() public {
        test_Board_FluidLite();
        uint256 amount = 1 ether; // 1 ETH
        vm.prank(keeper);

        ark.requestWithdrawal(amount - 1);
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
}
