// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/SiloVaultArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Raft} from "../../src/contracts/Raft.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract SonicArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    SiloVaultArk public ark;
    IERC4626 public silo;
    IERC20 public usdce;
    ArkParams public params;

    address public constant SILO_ADDRESS =
        0x322e1d5384aa4ED66AeCa770B95686271de61dc3;
    address public constant USDCE_ADDRESS =
        0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    address public constant GAUGE = 0x2D3d269334485d2D876df7363e1A50b13220a7D8;

    address public constant WRAPPED_SONIC =
        0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address public constant SILO_TOKEN =
        0x53f753E4B17F4075D6fa2c6909033d224b81e698;

    uint256 forkBlock = 13716442; // Specified block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("sonic"), forkBlock);

        usdce = IERC20(USDCE_ADDRESS);
        silo = IERC4626(SILO_ADDRESS);

        params = ArkParams({
            name: "USDCE Sonic ERC4626 Ark",
            details: "USDCE Sonic ERC4626 Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDCE_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new SiloVaultArk(SILO_ADDRESS, params);

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

        vm.makePersistent(address(ark));
        vm.makePersistent(address(silo));
        vm.makePersistent(address(usdce));
        vm.makePersistent(GAUGE);
    }

    function test_Constructor() public {
        // Invalid silo address
        vm.expectRevert(abi.encodeWithSignature("InvalidSiloAddress()"));
        ark = new SiloVaultArk(address(0), params);

        // Asset mismatch
        vm.mockCall(
            SILO_ADDRESS,
            abi.encodeWithSelector(IERC4626.asset.selector),
            abi.encode(address(9))
        );
        vm.expectRevert(abi.encodeWithSignature("ERC4626AssetMismatch()"));
        ark = new SiloVaultArk(SILO_ADDRESS, params);
        vm.clearMockedCalls();

        // Valid constructor
        ark = new SiloVaultArk(SILO_ADDRESS, params);

        assertEq(
            address(ark.silo()),
            SILO_ADDRESS,
            "Vault address should match"
        );
        assertEq(
            address(ark.asset()),
            USDCE_ADDRESS,
            "Token address should match USDCE"
        );
        assertEq(
            ark.name(),
            "USDCE Sonic ERC4626 Ark",
            "Ark name should match"
        );
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDCE
        deal(USDCE_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdce.forceApprove(address(ark), amount);

        uint256 initialVaultBalance = silo.balanceOf(address(ark));

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDCE_ADDRESS, amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalVaultBalance = silo.balanceOf(address(ark));
        assertGt(
            finalVaultBalance,
            initialVaultBalance,
            "Vault balance should increase"
        );

        uint256 totalAssets = ark.totalAssets();

        vm.warp(block.timestamp + 365 days);

        uint256 totalAssetsAfterYear = ark.totalAssets();

        assertGt(
            totalAssetsAfterYear,
            totalAssets,
            "Total assets should have increased after a year"
        );
    }

    function test_Disembark() public {
        uint256 amount = 1000 * 1e6; // 1000 USDCE
        deal(USDCE_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdce.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));

        uint256 initialUSDCEBalance = usdce.balanceOf(commander);
        uint256 amountToDisembark = IERC4626(SILO_ADDRESS).maxWithdraw(
            address(ark)
        );

        vm.expectEmit();
        emit Disembarked(commander, USDCE_ADDRESS, amountToDisembark);

        ark.disembark(amountToDisembark, bytes(""));
        vm.stopPrank();

        uint256 finalUSDCEBalance = usdce.balanceOf(commander);
        assertEq(
            finalUSDCEBalance,
            initialUSDCEBalance + amountToDisembark,
            "USDCE balance should increase by disembarked amount"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDCE
        deal(USDCE_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdce.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
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
        uint256 amount = 1000 * 1e6; // 1000 USDCE
        deal(USDCE_ADDRESS, commander, amount * 3);

        vm.startPrank(commander);
        usdce.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.rollFork(forkId, 14201704); // Fast forward few days

        vm.prank(keeper);
        Raft(raft).harvest(address(ark), bytes(""));

        uint256 siloBalance = Raft(raft).obtainedTokens(
            address(ark),
            SILO_TOKEN
        );
        uint256 sonicBalance = Raft(raft).obtainedTokens(
            address(ark),
            WRAPPED_SONIC
        );

        assertGt(
            siloBalance,
            0,
            "Harvested Silo balance should be greater than 0"
        );
        assertGt(
            sonicBalance,
            0,
            "Harvested Sonic balance should be greater than 0"
        );
    }
}
