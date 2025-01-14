// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import "../../src/contracts/arks/MorphoVaultArk.sol";
import "../../src/events/IArkEvents.sol";

import {IArk} from "../../src/interfaces/IArk.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract MetaMorphoArkTestFork is Test, IArkEvents, ArkTestBase {
    MorphoVaultArk public ark;

    address public constant METAMORPHO_ADDRESS =
        0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;
    address public constant MORPHO_URD_FACTORY =
        0x9baA51245CDD28D8D74Afe8B3959b616E9ee7c8D;

    IMetaMorpho public metaMorpho;
    IERC20 public asset;

    uint256 forkBlock = 20376149; // Adjust this to a suitable block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        metaMorpho = IMetaMorpho(METAMORPHO_ADDRESS);
        asset = IERC20(metaMorpho.asset());

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(asset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new MorphoVaultArk(
            METAMORPHO_ADDRESS,
            MORPHO_URD_FACTORY,
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
    }

    function test_Board_MetaMorphoArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6;
        deal(address(asset), commander, amount);

        vm.startPrank(commander);
        asset.approve(address(ark), amount);

        // Expect the deposit call to MetaMorpho
        vm.expectCall(
            METAMORPHO_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.deposit.selector,
                amount,
                address(ark)
            )
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(asset), amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertEq(
            assetsAfterDeposit,
            amount - 1,
            "Total assets should equal deposited amount"
        );

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 1 days);

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual >= assetsAfterDeposit,
            "Assets should not decrease after accrual"
        );
    }

    function test_Disembark_MetaMorphoArk_fork() public {
        // First, board some assets
        test_Board_MetaMorphoArk_fork();

        uint256 initialBalance = asset.balanceOf(commander);
        uint256 amountToWithdraw = 500 * 10 ** 6;

        vm.prank(commander);

        // Expect the withdraw call to MetaMorpho
        vm.expectCall(
            METAMORPHO_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.withdraw.selector,
                amountToWithdraw,
                address(ark),
                address(ark)
            )
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, address(asset), amountToWithdraw);

        ark.disembark(amountToWithdraw, bytes(""));

        uint256 finalBalance = asset.balanceOf(commander);
        assertEq(
            finalBalance - initialBalance,
            amountToWithdraw,
            "Commander should receive withdrawn amount"
        );

        uint256 remainingAssets = ark.totalAssets();
        assertTrue(
            remainingAssets < 1000 * 10 ** 6,
            "Remaining assets should be less than initial deposit"
        );
    }

    function test_TotalAssets_MetaMorphoArk_fork() public {
        // Deposit some assets first
        test_Board_MetaMorphoArk_fork();

        uint256 initialTotalAssets = ark.totalAssets();

        // Warp time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        uint256 newTotalAssets = ark.totalAssets();

        // Total assets should not decrease over time (assuming no withdrawals)
        assertTrue(
            newTotalAssets > initialTotalAssets,
            "Total assets should increase over time"
        );
    }

    function test_Constructor_MetaMorphoArk_AddressZero_fork() public {
        // Arrange
        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(asset),
            depositCap: 1000,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Act
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new MorphoVaultArk(address(0), address(0), params);
    }
}
