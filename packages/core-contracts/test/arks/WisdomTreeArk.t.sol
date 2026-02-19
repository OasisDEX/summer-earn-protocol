// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/WisdomTreeArk.sol";
import "../../src/events/IArkEvents.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract WisdomTreeArkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    WisdomTreeArk public ark;
    IERC20 public usdt;
    ArkParams public params;

    address public constant USDT_ADDRESS =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public targetWallet;

    uint256 forkBlock = 21666256;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdt = IERC20(USDT_ADDRESS);
        targetWallet = makeAddr("targetWallet");

        params = ArkParams({
            name: "USDT WisdomTree Ark",
            details: "USDT WisdomTree Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDT_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new WisdomTreeArk(targetWallet, params);

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

    function test_Constructor() public {
        vm.expectRevert(WisdomTreeArk.InvalidTargetWallet.selector);
        new WisdomTreeArk(address(0), params);

        assertEq(
            ark.targetWallet(),
            targetWallet,
            "Target wallet should match"
        );
        assertEq(address(ark.asset()), USDT_ADDRESS, "Asset should match");
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6;
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);

        uint256 initialTargetBalance = usdt.balanceOf(targetWallet);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 finalTargetBalance = usdt.balanceOf(targetWallet);
        assertEq(
            finalTargetBalance,
            initialTargetBalance + amount,
            "Target wallet should receive tokens"
        );
        assertEq(
            ark.totalAssets(),
            amount,
            "Total assets should match boarded amount"
        );
    }

    function test_Disembark() public {
        uint256 amount = 1000 * 1e6;
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Simulate manual return of funds to Ark
        deal(USDT_ADDRESS, address(ark), amount);

        vm.startPrank(commander);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();

        assertEq(
            ark.totalAssets(),
            0,
            "Total assets should be 0 after disembark"
        );
        assertEq(
            usdt.balanceOf(commander),
            amount,
            "Commander should receive tokens back"
        );
    }

    function test_Disembark_InsufficientFunds() public {
        uint256 amount = 1000 * 1e6;
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Try to disembark more than deposited
        vm.startPrank(commander);
        vm.expectRevert(WisdomTreeArk.InsufficientDepositedAssets.selector);
        ark.disembark(amount + 1, bytes(""));
        vm.stopPrank();
    }

    function test_Disembark_InsufficientFundsInArk() public {
        uint256 amount = 1000 * 1e6;
        deal(USDT_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdt.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Do NOT fund the Ark manually (or fund less)
        deal(USDT_ADDRESS, address(ark), amount - 1);

        vm.startPrank(commander);
        // Expect revert due to insufficient balance in Ark contract
        vm.expectRevert(WisdomTreeArk.InsufficientFundsInArk.selector);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();
    }
}
