// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStakingTestBase} from "./SummerStakingTestBase.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {ISummerStaking} from "../../src/interfaces/ISummerStaking.sol";

contract SummerStakingCoreTest is SummerStakingTestBase {
    address public user3 = address(0x1003);

    function setUp() public override {
        super.setUp();
    }

    // ============ RESCUE TOKEN TESTS ==========

    function test_RescueToken_Success_TransfersFullBalance() public {
        // Arrange: fund staking contract with an arbitrary ERC20 (rewardToken)
        uint256 amount = REWARD_AMOUNT * 5;
        address receiver = user3;
        deal(address(rewardToken), address(aStaking), amount);
        assertEq(
            IERC20(address(rewardToken)).balanceOf(address(aStaking)),
            amount,
            "staking contract should have the amount"
        );
        uint256 receiverBefore = IERC20(address(rewardToken)).balanceOf(
            receiver
        );

        // Act: governor rescues the tokens to receiver
        vm.prank(address(timelockA));
        aStaking.rescueToken(address(rewardToken), receiver);

        // Assert: staking contract drained; receiver received full amount
        assertEq(IERC20(address(rewardToken)).balanceOf(address(aStaking)), 0);
        assertEq(
            IERC20(address(rewardToken)).balanceOf(receiver),
            receiverBefore + amount
        );
    }

    function test_Revert_RescueToken_ByNonGovernor() public {
        // Non-governor should not be able to call rescueToken
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user1
            )
        );
        aStaking.rescueToken(address(rewardToken), user2);
    }

    function test_Revert_RescueToken_WrappedSummerToken() public {
        // Governor attempting to rescue WRAPPED_SUMMER_TOKEN should revert
        address wrapped = address(aStaking.WRAPPED_SUMMER_TOKEN());
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerStaking.Staking_InvalidAddress.selector,
                "Cannot rescue wrapped summer token"
            )
        );
        aStaking.rescueToken(wrapped, user1);
    }

    function test_RescueToken_ZeroBalance_NoOp() public {
        // New token with zero balance in staking contract
        MockERC20 emptyToken = new MockERC20();
        address receiver = user2;
        uint256 receiverBefore = emptyToken.balanceOf(receiver);
        assertEq(emptyToken.balanceOf(address(aStaking)), 0);

        // Governor calls rescue; should not change balances and should not revert
        vm.prank(address(timelockA));
        aStaking.rescueToken(address(emptyToken), receiver);

        assertEq(emptyToken.balanceOf(address(aStaking)), 0);
        assertEq(emptyToken.balanceOf(receiver), receiverBefore);
    }
}
