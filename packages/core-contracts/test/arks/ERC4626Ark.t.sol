// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/ERC4626Ark.sol";
import "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract ERC4626ArkTestFork is Test, IArkEvents {
    ERC4626Ark public ark;
    address public governor = address(1);
    address public raft = address(2);
    address public tipJar = address(3);
    address public commander = address(4);

    address public constant VAULT_ADDRESS =
        0xda00000035fef4082F78dEF6A8903bee419FbF8E;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IERC4626 public vault;
    IERC20 public usdc;
    ArkParams public params;

    uint256 forkBlock = 20000000; // A recent block number
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        vault = IERC4626(VAULT_ADDRESS);

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: tipJar,
                raft: raft
            })
        );

        params = ArkParams({
            name: "USDC ERC4626 Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max
        });

        ark = new ERC4626Ark(VAULT_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
        vm.stopPrank();
    }

    function test_Constructor() public {
        // Invalid vault address
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        ark = new ERC4626Ark(address(0), params);

        // Asset mismatch
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC4626.asset.selector),
            abi.encode(address(9))
        );
        vm.expectRevert(abi.encodeWithSignature("ERC4626AssetMismatch()"));
        ark = new ERC4626Ark(VAULT_ADDRESS, params);
        vm.clearMockedCalls();

        // Valid constructor
        ark = new ERC4626Ark(VAULT_ADDRESS, params);

        assertEq(
            address(ark.vault()),
            VAULT_ADDRESS,
            "Vault address should match"
        );
        assertEq(
            address(ark.token()),
            USDC_ADDRESS,
            "Token address should match USDC"
        );
        assertEq(ark.name(), "USDC ERC4626 Ark", "Ark name should match");
    }

    function test_Rate() public view {
        assertEq(ark.rate(), 1000 ether, "Rate should return max uint256");
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);

        uint256 initialVaultBalance = vault.balanceOf(address(ark));

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC_ADDRESS, amount);

        ark.board(amount);
        vm.stopPrank();

        uint256 finalVaultBalance = vault.balanceOf(address(ark));
        assertGt(
            finalVaultBalance,
            initialVaultBalance,
            "Vault balance should increase"
        );
    }

    function test_Disembark() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount);

        uint256 initialUSDCBalance = usdc.balanceOf(commander);
        uint256 amountToDisembark = IERC4626(VAULT_ADDRESS).maxWithdraw(
            address(ark)
        );

        vm.expectEmit();
        emit Disembarked(commander, USDC_ADDRESS, amountToDisembark);

        ark.disembark(amountToDisembark);
        vm.stopPrank();

        uint256 finalUSDCBalance = usdc.balanceOf(commander);
        assertEq(
            finalUSDCBalance,
            initialUSDCBalance + amountToDisembark,
            "USDC balance should increase by disembarked amount"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount);
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        assertApproxEqRel(
            totalAssets,
            amount,
            1e10,
            "Total assets should be at least the deposited amount"
        );
    }

    function test_Harvest() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days); // Fast forward 1 year

        uint256 harvestedAmount = ark.harvest(address(0), "");
        assertEq(
            harvestedAmount,
            0,
            "Harvested amount should be 0 for auto-compounding vaults"
        );

        uint256 totalAssetsAfterYear = ark.totalAssets();
        assertGt(
            totalAssetsAfterYear,
            amount,
            "Total assets should have increased after a year"
        );
    }
}
