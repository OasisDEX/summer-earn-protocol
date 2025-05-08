// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/OriginETHArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IOriginETH} from "../../src/interfaces/origin/IOriginETH.sol";
import {IOriginETHVault} from "../../src/interfaces/origin/IOriginETHVault.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";
import {IWETH} from "../../src/interfaces/misc/IWETH.sol";

contract OriginETHArkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    OriginETHArk public ark;
    IOriginETH public originETH;
    IOriginETHVault public originETHVault;
    IERC20 public weth;
    ArkParams public params;

    address public constant ORIGINETH_ADDRESS =
        0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3; // IOriginETH address
    address public constant ORIGIN_ETH_VAULT_ADDRESS =
        0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab; // IOriginETH address
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet WETH address
    address public constant OETH_WETH_ARM =
        0x6bac785889A4127dB0e0CeFEE88E0a9F1Aaf3cC7; // OETH WETH ARM address

    uint256 forkBlock = 21666256; // A recent block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        weth = IERC20(WETH_ADDRESS);
        originETH = IOriginETH(ORIGINETH_ADDRESS);
        originETHVault = IOriginETHVault(ORIGIN_ETH_VAULT_ADDRESS);
        params = ArkParams({
            name: "WETH OriginETH Ark",
            details: "WETH OriginETH Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: WETH_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new OriginETHArk(ORIGINETH_ADDRESS, OETH_WETH_ARM, params);

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
        // Invalid OriginETH address
        vm.expectRevert(abi.encodeWithSignature("InvalidOriginETHAddress()"));
        ark = new OriginETHArk(address(0), OETH_WETH_ARM, params);

        // Valid constructor
        ark = new OriginETHArk(ORIGINETH_ADDRESS, OETH_WETH_ARM, params);

        assertEq(
            address(ark.originETH()),
            ORIGINETH_ADDRESS,
            "OriginETH address should match"
        );
        assertEq(
            address(ark.asset()),
            WETH_ADDRESS,
            "Asset address should match WETH"
        );
        assertEq(ark.name(), "WETH OriginETH Ark", "Ark name should match");
    }

    function test_Board() public {
        uint256 amount = 1 ether; // 1 WETH

        // Fund the commander with WETH
        vm.deal(commander, 2 ether);
        vm.startPrank(commander);

        // Wrap ETH to WETH
        IWETH(WETH_ADDRESS).deposit{value: 2 ether}();

        // Approve the ark to spend WETH
        weth.forceApprove(address(ark), amount);

        // We need to mock the OriginETH.mint call since we can't fully simulate it in the test
        vm.mockCall(
            ORIGINETH_ADDRESS,
            abi.encodeWithSelector(
                IOriginETH.mint.selector,
                address(ark),
                amount,
                0
            ),
            abi.encode()
        );

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        // Board the tokens - use empty bytes for default minShares (0)
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.clearMockedCalls();
    }

    function test_BoardWithMinShares() public {
        uint256 amount = 1 ether; // 1 WETH
        uint256 minShares = 0.9 ether; // Minimum expected shares

        // Fund the commander with WETH
        vm.deal(commander, 2 ether);
        vm.startPrank(commander);

        // Wrap ETH to WETH
        IWETH(WETH_ADDRESS).deposit{value: 2 ether}();

        // Approve the ark to spend WETH
        weth.forceApprove(address(ark), amount);

        // We need to mock the OriginETH.mint call since we can't fully simulate it in the test
        vm.mockCall(
            ORIGINETH_ADDRESS,
            abi.encodeWithSelector(
                IOriginETH.mint.selector,
                address(ark),
                amount,
                minShares
            ),
            abi.encode()
        );

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        // Board the tokens with minShares parameter
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.clearMockedCalls();
    }

    function test_Disembark_OriginETH() public {
        test_Board();
        uint256 amount = 1 ether; // 1 WETH

        vm.startPrank(commander);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();
    }

    function test_TotalAssets() public {
        uint256 amount = 1 ether; // 1 WETH

        // Fund the ark directly with WETH for testing totalAssets
        deal(address(weth), address(ark), amount);
        deal(address(weth), address(commander), amount);

        // board the tokens
        vm.startPrank(commander);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();

        assertEq(
            totalAssets,
            2 * amount,
            "Total assets should match the WETH balance + OriginETH balance"
        );
    }

    function test_RequestWithdrawal() public {
        uint256 amount = 1 ether; // 1 WETH

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(weth), address(commander), amount);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        assertEq(
            ark.assetsInWithdrawalQueue(),
            amount,
            "Assets in withdrawal queue should match the withdrawal amount"
        );

        vm.clearMockedCalls();
    }

    function test_ClaimWithdrawal_ClaimDelayNotMet() public {
        // Set withdrawal request ID manually (would normally be set by requestWithdrawal)
        uint256 requestId = 174;
        uint256 amount = 1 ether; // 1 WETH

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(weth), address(commander), amount);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        vm.expectRevert("Claim delay not met");
        vm.startPrank(commander);
        ark.claimWithdrawal();
        vm.stopPrank();

        // Verify the request ID was reset
        assertEq(
            ark.withdrawalRequestId(),
            requestId,
            "Withdrawal request ID should be unchanged"
        );
    }

    function test_ClaimWithdrawal_QueuePendingLiquidity() public {
        // Set withdrawal request ID manually (would normally be set by requestWithdrawal)
        uint256 requestId = 174;
        uint256 amount = 1 ether; // 1 WETH

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(weth), address(commander), amount);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 minutes);

        vm.expectRevert("Queue pending liquidity");
        vm.startPrank(commander);
        ark.claimWithdrawal();
        vm.stopPrank();

        // Verify the request ID was reset
        assertEq(
            ark.withdrawalRequestId(),
            requestId,
            "Withdrawal request ID should be unchanged"
        );
    }

    function test_ClaimWithdrawal_WithdrawalRequestClaimed() public {
        // Set withdrawal request ID manually (would normally be set by requestWithdrawal)
        uint256 requestId = 174;
        uint256 amount = 1 ether; // 1 WETH

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(weth), address(commander), amount);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssetsBeforeRequest = ark.totalAssets();
        assertEq(
            totalAssetsBeforeRequest,
            amount,
            "Before request, total assets should be equal to the withdrawal amount"
        );

        vm.startPrank(commander);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 minutes);

        uint256 totalAssetsBeforeClaim = ark.totalAssets();
        assertEq(
            totalAssetsBeforeClaim,
            amount,
            "Before claim, total assets should be equal to the withdrawal amount"
        );

        deal(address(weth), address(originETHVault), 1000 * amount);
        vm.startPrank(commander);
        ark.claimWithdrawal();
        vm.stopPrank();

        uint256 totalAssetsAfter = ark.totalAssets();
        assertEq(
            totalAssetsAfter,
            amount,
            "After claim, total assets should be equal to the withdrawal amount"
        );

        // Verify the request ID was reset
        assertEq(
            ark.withdrawalRequestId(),
            0,
            "Withdrawal request ID should be reset to 0"
        );
    }

    function test_ClaimWithdrawal_NoRequestId() public {
        // Make sure withdrawalRequestId is 0
        assertEq(
            ark.withdrawalRequestId(),
            0,
            "Withdrawal request ID should be 0"
        );

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        // Should revert with NoWithdrawalRequest
        vm.startPrank(commander);
        vm.expectRevert(abi.encodeWithSignature("NoWithdrawalToClaim()"));
        ark.claimWithdrawal();
        vm.stopPrank();
    }

    function test_WithdrawableAssets() public {
        uint256 arkBalance = 1 ether; // 1 WETH in Ark
        uint256 originBalance = 2 ether; // 2 OETH in Ark
        uint256 armBalance = 1.5 ether; // 1.5 WETH in ARM

        // Fund the Ark with WETH
        deal(address(weth), address(ark), arkBalance);
        assertEq(
            weth.balanceOf(address(ark)),
            arkBalance,
            "WETH balance should match"
        );

        // Fund the Ark with OETH
        deal(address(weth), address(commander), originBalance);
        vm.startPrank(commander);
        weth.forceApprove(address(originETHVault), originBalance);
        originETHVault.mint(address(weth), originBalance, originBalance);
        originETH.transfer(address(ark), originBalance);
        vm.stopPrank();
        assertEq(
            originETH.balanceOf(address(ark)),
            originBalance,
            "OriginETH balance should match"
        );

        // Fund the ARM with WETH
        deal(address(weth), OETH_WETH_ARM, armBalance);
        assertEq(
            weth.balanceOf(OETH_WETH_ARM),
            armBalance,
            "WETH balance should match"
        );

        // Calculate expected withdrawable assets
        // Ark's WETH balance + minimum of (Ark's OETH balance, ARM's WETH balance)
        uint256 expectedWithdrawable = arkBalance +
            (originBalance > armBalance ? armBalance : originBalance);

        // Call withdrawableTotalAssets() - We'll need to expose it for testing
        vm.prank(commander);
        uint256 actualWithdrawable = ark.withdrawableTotalAssets();

        vm.startPrank(commander);
        ark.disembark(expectedWithdrawable, bytes(""));
        vm.stopPrank();

        assertEq(weth.balanceOf(address(ark)), 0, "WETH balance should be 0");
        assertEq(
            originETH.balanceOf(address(ark)),
            0.5 ether,
            "OriginETH balance should be 0.5 ether."
        );
        assertEq(weth.balanceOf(OETH_WETH_ARM), 0, "WETH balance should be 0");

        assertEq(
            actualWithdrawable,
            expectedWithdrawable,
            "Withdrawable assets should match expected value"
        );
    }
}
