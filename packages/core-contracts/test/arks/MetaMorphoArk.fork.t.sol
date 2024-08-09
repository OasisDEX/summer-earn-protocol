// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {IMorpho, Id, MarketParams} from "morpho-blue/interfaces/IMorpho.sol";
import {IMetaMorpho, IMetaMorphoBase} from "metamorpho/interfaces/IMetaMorpho.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import "../../src/contracts/arks/MetaMorphoArk.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/events/IArkEvents.sol";

contract MetaMorphoArkTestFork is Test, IArkEvents, ArkTestHelpers {
    MetaMorphoArk public ark;
    address public governor = address(1);
    address public raft = address(2);
    address public tipJar = address(3);
    address public commander = address(4);

    address public constant METAMORPHO_ADDRESS =
        0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    IMetaMorpho public metaMorpho;
    IERC20 public asset;
    IProtocolAccessManager accessManager;
    IConfigurationManager configurationManager;

    uint256 forkBlock = 20376149; // Adjust this to a suitable block number
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        metaMorpho = IMetaMorpho(METAMORPHO_ADDRESS);
        asset = IERC20(metaMorpho.asset());

        accessManager = new ProtocolAccessManager(governor);

        configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: tipJar,
                raft: raft
            })
        );

        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(asset),
            depositCap: type(uint256).max,
            moveFromMax: type(uint256).max,
            moveToMax: type(uint256).max
        });

        ark = new MetaMorphoArk(METAMORPHO_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
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

        // Expect the ArkPoked event to be emitted
        vm.expectEmit();
        emit ArkPoked(metaMorpho.convertToAssets(WAD), block.timestamp);

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(asset), amount);

        // Expect the poke call to Ark
        vm.expectCall(address(ark), abi.encodeWithSelector(IArk.poke.selector));

        // Act
        ark.board(amount);
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

        // Check rate
        uint256 currentRate = ark.rate();
        assertTrue(currentRate > 0, "Rate should be greater than zero");
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

        // Expect the poke call to Ark
        vm.expectCall(address(ark), abi.encodeWithSelector(IArk.poke.selector));

        ark.disembark(amountToWithdraw);

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

    function test_Poke_MetaMorphoArk_fork() public {
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

        // Case 1 - Ark poked in the right time
        vm.expectEmit();
        emit ArkPoked(metaMorpho.convertToAssets(WAD), block.timestamp);
        ark.poke();

        uint256 currentPrice = metaMorpho.convertToAssets(WAD);
        vm.mockCall(
            address(metaMorpho),
            abi.encodeWithSignature("convertToAssets(uint256)", WAD),
            abi.encode(currentPrice)
        );

        // Case 2 - Ark poked too soon
        vm.expectEmit();
        emit ArkPokedTooSoon();
        ark.poke();

        vm.warp(block.timestamp + 30 days);

        // Case 3 - Ark poked and total assets did not change (mock)
        vm.expectEmit();
        emit ArkPokedNoChange();
        ark.poke();

        vm.mockCall(
            address(metaMorpho),
            abi.encodeWithSignature("convertToAssets(uint256)", WAD),
            abi.encode(currentPrice + 1)
        );

        uint256 finalTotalAssets = ark.totalAssets();
        assertTrue(
            finalTotalAssets > newTotalAssets,
            "Total assets should increase after poke"
        );
    }

    function test_Constructor_MetaMorphoArk_AddressZero_fork() public {
        // Arrange
        ArkParams memory params = ArkParams({
            name: "TestArk",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(asset),
            depositCap: 1000,
            moveFromMax: type(uint256).max,
            moveToMax: type(uint256).max
        });

        // Act
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new MetaMorphoArk(address(0), params);
    }
}
