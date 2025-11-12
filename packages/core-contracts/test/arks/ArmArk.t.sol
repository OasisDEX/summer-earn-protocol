// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/ArmArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {IArm} from "../../src/interfaces/origin/IArm.sol";
import {IArkWithWithdrawalRequest} from "../../src/interfaces/IArkWithWithdrawalRequest.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";
import {IWETH} from "../../src/interfaces/misc/IWETH.sol";

contract ArmArkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    ArmArk public ark;
    IArm public arm;
    IERC20 public weth;
    ArkParams public params;
    address public bufferArk;

    // ARM and ARM Zapper addresses from the provided information
    address public constant ARM_ADDRESS =
        0x85B78AcA6Deae198fBF201c82DAF6Ca21942acc6; // ARM address
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet WETH address

    uint256 forkBlock = 22420334; // A recent block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(WETH_ADDRESS, "Test ARM Fleet");
        bufferArk = _bufferArk;
        commander = _commander;
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        weth = IERC20(WETH_ADDRESS);
        arm = IArm(ARM_ADDRESS);

        params = ArkParams({
            name: "WETH ARM Ark",
            details: "WETH ARM Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: WETH_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new ArmArk(ARM_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantCuratorRole(
            address(address(commander)),
            address(curator)
        );
        IFleetCommanderConfigProvider(commander).addArk(address(ark));
        vm.stopPrank();

        vm.startPrank(curator);
        ark.whitelistRouter(ODOS_ROUTER_MAINNET, true);
        vm.stopPrank();

        vm.makePersistent(ARM_ADDRESS);
        vm.makePersistent(WETH_ADDRESS);
        vm.makePersistent(commander);
        vm.makePersistent(curator);
        vm.makePersistent(governor);
        vm.makePersistent(address(ark));
    }

    function test_Constructor() public {
        // Invalid ARM address
        vm.expectRevert(abi.encodeWithSignature("InvalidArmAddress()"));
        ark = new ArmArk(address(0), params);

        // Valid constructor
        ark = new ArmArk(ARM_ADDRESS, params);

        assertEq(address(ark.arm()), ARM_ADDRESS, "ARM address should match");
        assertEq(
            address(ark.asset()),
            WETH_ADDRESS,
            "Asset address should match WETH"
        );
        assertEq(ark.name(), "WETH ARM Ark", "Ark name should match");
    }

    function test_Board() public {
        _test_Board(1 ether);
    }

    function _test_Board(uint amount) internal {
        // Fund the commander with WETH
        vm.deal(commander, amount * 2);
        vm.startPrank(commander);

        // Wrap ETH to WETH
        IWETH(WETH_ADDRESS).deposit{value: amount}();

        // Approve the ark to spend WETH
        weth.forceApprove(address(ark), amount);

        uint256 armBalanceBefore = arm.balanceOf(address(ark));

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        // Board the tokens - use empty bytes for default data
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 armBalanceAfter = arm.balanceOf(address(ark));
        assertGt(
            armBalanceAfter,
            armBalanceBefore,
            "ARM balance should increase after boarding"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1 ether;

        // Initial total assets should be 0
        assertEq(ark.totalAssets(), 0, "Initial total assets should be 0");

        // Fund and board
        vm.deal(commander, 2 ether);
        vm.startPrank(commander);
        IWETH(WETH_ADDRESS).deposit{value: 2 ether}();
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Total assets should now include ARM balance
        uint256 totalAssets = ark.totalAssets();
        assertGt(
            totalAssets,
            0,
            "Total assets should be greater than 0 after boarding"
        );

        // Should equal ARM balance + WETH balance + withdrawal queue assets
        uint256 expectedAssets = amount;
        assertApproxEqAbs(
            totalAssets,
            expectedAssets,
            1,
            "Total assets calculation should be correct"
        );
    }

    function test_Disembark() public {
        uint256 amount = 0.5 ether;
        uint256 wethBalanceBefore = weth.balanceOf(address(ark));
        deal(WETH_ADDRESS, address(ark), amount); // fund the ark with WETH
        vm.startPrank(commander);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();

        uint256 wethBalanceAfter = weth.balanceOf(address(ark));
        assertGe(
            wethBalanceAfter,
            wethBalanceBefore,
            "WETH balance should increase or stay same after disembark"
        );
    }

    function test_RequestWithdrawal() public {
        _test_RequestWithdrawal(1 ether, 0.5 ether);
    }

    function _test_RequestWithdrawal(
        uint depositAmount,
        uint withdrawalAmount
    ) internal returns (uint assetsInWithdrawalQueue) {
        _test_Board(depositAmount);

        uint256 armBalance = arm.convertToAssets(arm.balanceOf(address(ark)));
        assertGt(
            armBalance,
            0,
            "Should have ARM balance before withdrawal request"
        );

        // Check initial state
        assertEq(
            ark.withdrawalRequestId(),
            0,
            "Initial withdrawal request ID should be 0"
        );
        assertFalse(
            ark.isWithdrawalClaimRequired(),
            "Should not require withdrawal claim initially"
        );

        vm.startPrank(keeper);
        uint balanceBeforeWithdrawal = ark.totalAssets();
        ark.requestWithdrawal(withdrawalAmount);
        vm.stopPrank();

        assetsInWithdrawalQueue = ark.assetsInWithdrawalQueue();

        // Check state after withdrawal request
        assertGt(
            ark.withdrawalRequestId(),
            0,
            "Withdrawal request ID should be set"
        );
        assertTrue(
            ark.isWithdrawalClaimRequired(),
            "Should require withdrawal claim after request"
        );

        assertEq(
            assetsInWithdrawalQueue,
            withdrawalAmount == type(uint256).max
                ? balanceBeforeWithdrawal
                : withdrawalAmount - 1, // -1 to account for rounding down
            "Should have assets in withdrawal queue"
        );
    }

    function test_ClaimWithdrawal() public {
        uint assetsInWithdrawalQueue = _test_RequestWithdrawal(
            1 ether,
            0.5 ether
        );

        vm.startPrank(keeper);
        vm.expectRevert(abi.encode("Claim delay not met"));
        ark.claimWithdrawal();

        vm.warp(block.timestamp + 1 days);
        ark.claimWithdrawal();
        vm.stopPrank();

        uint256 wethInArkAfterClaim = weth.balanceOf(address(ark));
        assertApproxEqAbs(
            wethInArkAfterClaim,
            assetsInWithdrawalQueue,
            1,
            "WETH in Ark should be equal to assets in withdrawal queue"
        );
    }

    function test_ClaimWithdrawal_MaxAmount() public {
        uint assetsInWithdrawalQueue = _test_RequestWithdrawal(
            100 ether,
            type(uint256).max
        );

        vm.startPrank(keeper);
        vm.expectRevert(abi.encode("Claim delay not met"));
        ark.claimWithdrawal();

        vm.warp(block.timestamp + 1 days);
        ark.claimWithdrawal();
        vm.stopPrank();

        uint256 wethInArkAfterClaim = weth.balanceOf(address(ark));
        assertEq(wethInArkAfterClaim, assetsInWithdrawalQueue);
    }
    function test_ClaimWithdrawal_MaxAmountNoLiquidity() public {
        _test_RequestWithdrawal(100 ether, type(uint256).max);

        vm.startPrank(keeper);
        vm.expectRevert(abi.encode("Claim delay not met"));
        ark.claimWithdrawal();

        // overwrite the WETH balance of the ARM address
        deal(WETH_ADDRESS, ARM_ADDRESS, 50 ether);

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(abi.encode("Queue pending liquidity"));
        ark.claimWithdrawal();
        vm.stopPrank();
    }
    function test_RequestWithdrawal_MaxAmount() public {
        test_Board();

        uint256 armBalance = arm.convertToAssets(arm.balanceOf(address(ark)));

        vm.startPrank(keeper);
        ark.requestWithdrawal(type(uint256).max);
        vm.stopPrank();

        assertGt(
            ark.withdrawalRequestId(),
            0,
            "Withdrawal request ID should be set"
        );
        assertTrue(
            ark.isWithdrawalClaimRequired(),
            "Should require withdrawal claim"
        );
        assertApproxEqAbs(
            ark.assetsInWithdrawalQueue(),
            armBalance,
            1,
            "Should request full ARM balance - up to 1 wei"
        );
    }

    function test_RequestWithdrawal_AlreadyRequested() public {
        test_RequestWithdrawal();

        vm.startPrank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("WithdrawalAlreadyRequested()")
        );
        ark.requestWithdrawal(1 ether);
        vm.stopPrank();
    }

    function test_ClaimWithdrawal_NoRequest() public {
        vm.startPrank(keeper);
        vm.expectRevert(abi.encodeWithSignature("NoWithdrawalToClaim()"));
        ark.claimWithdrawal();
        vm.stopPrank();
    }

    function test_WithdrawUsingSwap() public {
        test_Board();

        // Prepare swap data (this would be real swap data in practice)
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: ODOS_ROUTER_MAINNET,
                swapCalldata: hex"" // Would contain actual swap calldata
            });
        bytes memory data = abi.encode(swapData);

        uint256 withdrawAmount = 0.5 ether;

        vm.startPrank(keeper);
        // todo: add a test for this
        vm.expectRevert();
        ark.withdrawUsingSwap(withdrawAmount, data);
        vm.stopPrank();
    }

    function test_AssetsInWithdrawalQueue_NoRequest() public view {
        assertEq(
            ark.assetsInWithdrawalQueue(),
            0,
            "Should return 0 when no withdrawal request"
        );
    }

    function test_IsWithdrawalClaimRequired_NoRequest() public view {
        assertFalse(
            ark.isWithdrawalClaimRequired(),
            "Should return false when no withdrawal request"
        );
    }

    function test_Harvest() public {
        test_Board();

        vm.startPrank(raft);
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest(bytes(""));
        vm.stopPrank();

        // ARM auto-compounds, so no rewards should be returned
        assertEq(
            rewardTokens.length,
            0,
            "Should return empty reward tokens array"
        );
        assertEq(
            rewardAmounts.length,
            0,
            "Should return empty reward amounts array"
        );
    }

    function test_WithdrawableTotalAssets() public {
        test_Board();

        uint256 withdrawableAssets = ark.withdrawableTotalAssets();
        uint256 expectedAssets = weth.balanceOf(address(ark));
        assertEq(0, expectedAssets, "Should be 0 - all assets are boarded");
        assertGe(
            withdrawableAssets,
            expectedAssets,
            "Withdrawable assets should include WETH and ARM balances"
        );
    }

    function test_Board_InsufficientBalance() public {
        uint256 amount = 1 ether;

        vm.startPrank(commander);
        // Don't fund the commander - should fail
        vm.expectRevert();
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_Disembark_InsufficientBalance() public {
        uint256 amount = 1 ether;

        vm.startPrank(commander);
        // Try to disembark without any boarding first
        vm.expectRevert();
        ark.disembark(amount, bytes(""));
        vm.stopPrank();
    }

    receive() external payable {}
}
