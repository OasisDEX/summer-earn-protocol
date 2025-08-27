// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {ISummerGovernorV2} from "../../src/interfaces/ISummerGovernorV2.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {xSumr} from "../../src/contracts/xSumr.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ExposedSummerGovernor, SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/*
 * @title SummerStaking Core Tests
 * @dev Test contract for SummerStaking contract constructor and core functionality.
 */
contract SummerStakingCoreTest is SummerGovernorV2TestBase {
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    uint256 public constant STAKE_AMOUNT = 1000 ether;

    SummerStaking public aStaking;
    SummerStaking public bStaking;

    function setUp() public override {
        super.setUp();

        // Setup test users with tokens
        deal(address(aSummerToken), user1, STAKE_AMOUNT * 2);
        deal(address(aSummerToken), user2, STAKE_AMOUNT * 2);

        vm.startPrank(whale);
        axSumr.burn(axSumr.balanceOf(whale));
        bxSumr.burn(bxSumr.balanceOf(whale));
        vm.stopPrank();

        aStaking = new SummerStaking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr)
        );
        bStaking = new SummerStaking(
            address(accessManagerB),
            address(bSummerToken),
            address(bxSumr)
        );
        vm.prank(address(timelockA));
        axSumr.setStakingModule(address(aStaking));
        vm.prank(address(timelockB));
        bxSumr.setStakingModule(address(bStaking));
    }

    // Helper function to create a fresh staking contract for isolated tests
    function createFreshStaking() internal returns (SummerStaking) {
        SummerStaking freshStaking = new SummerStaking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr)
        );

        // Set staking module so freshStaking can mint/burn xSumr
        vm.prank(address(timelockA));
        axSumr.setStakingModule(address(freshStaking));

        return freshStaking;
    }

    function test_Constructor_ValidParameters() public {
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        SummerStaking newStaking = new SummerStaking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr)
        );

        assertEq(address(newStaking.SUMMER_TOKEN()), address(aSummerToken));
        assertEq(address(newStaking.STAKED_SUMMER_TOKEN()), address(axSumr));
    }

    function test_Constructor_ZeroProtocolAccessManager() public {
        vm.expectRevert(); // Should revert due to ProtocolAccessManaged constructor
        new SummerStaking(
            address(0), // Zero protocol access manager
            address(aSummerToken),
            address(axSumr)
        );
    }

    function test_Constructor_ZeroSummerToken() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Summer token address cannot be zero"
            )
        );
        new SummerStaking(
            address(accessManagerA),
            address(0), // Zero summer token
            address(axSumr)
        );
    }

    function test_Constructor_ZeroXSumr() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "xSumr address cannot be zero"
            )
        );
        new SummerStaking(
            address(accessManagerA),
            address(aSummerToken),
            address(0) // Zero xSumr
        );
    }

    function test_Stake_ValidAmount() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // Approve staking contract to spend tokens
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 stakingSummerBalanceBefore = aSummerToken.balanceOf(
            address(aStaking)
        );
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Stake tokens
        vm.prank(user1);
        aStaking.stake(stakeAmount);

        // Check balances after staking
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore - stakeAmount
        );
        assertEq(
            aSummerToken.balanceOf(address(aStaking)),
            stakingSummerBalanceBefore + stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore + stakeAmount);
    }

    function test_Stake_ZeroAmount() public {
        // Approve staking contract (even for zero amount)
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), 0);

        // Stake zero amount
        vm.prank(user1);
        aStaking.stake(0);

        // Balances should remain unchanged
        assertEq(axSumr.balanceOf(user1), 0);
    }

    function test_Stake_InsufficientAllowance() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // Approve less than stake amount
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount - 1);

        // Attempt to stake - should revert
        vm.prank(user1);
        vm.expectRevert(); // SafeERC20 will revert on insufficient allowance
        aStaking.stake(stakeAmount);
    }

    function test_Stake_InsufficientBalance() public {
        uint256 stakeAmount = STAKE_AMOUNT * 10; // More than user has

        // Approve staking contract
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);

        // Attempt to stake - should revert
        vm.prank(user1);
        vm.expectRevert(); // ERC20 will revert on insufficient balance
        aStaking.stake(stakeAmount);
    }

    function test_Unstake_ValidAmount() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // First stake some tokens
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stake(stakeAmount);
        vm.stopPrank();

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 stakingSummerBalanceBefore = aSummerToken.balanceOf(
            address(aStaking)
        );
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Approve staking contract to burn xSumr
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount);

        // Unstake tokens
        vm.prank(user1);
        aStaking.unstake(stakeAmount);

        // Check balances after unstaking
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount
        );
        assertEq(
            aSummerToken.balanceOf(address(aStaking)),
            stakingSummerBalanceBefore - stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);
    }

    function test_Unstake_ZeroAmount() public {
        // First stake some tokens
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        aStaking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Unstake zero amount
        vm.prank(user1);
        aStaking.unstake(0);

        // xSumr balance should remain unchanged
        assertEq(axSumr.balanceOf(user1), STAKE_AMOUNT);
    }

    function test_Unstake_InsufficientAllowance() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // First stake some tokens
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stake(stakeAmount);
        vm.stopPrank();

        // Approve less than unstake amount
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount - 1);

        // Attempt to unstake - should revert
        vm.prank(user1);
        vm.expectRevert(); // SafeERC20 will revert on insufficient allowance
        aStaking.unstake(stakeAmount);
    }

    function test_Unstake_InsufficientBalance() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // First stake some tokens
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stake(stakeAmount);
        vm.stopPrank();

        // Approve staking contract
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount * 2);

        // Attempt to unstake more than available - should revert
        vm.prank(user1);
        vm.expectRevert(); // ERC20 will revert on insufficient balance
        aStaking.unstake(stakeAmount * 2);
    }

    function test_StakeUnstake_RoundTrip() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // Get initial balances
        uint256 initialSummerBalance = aSummerToken.balanceOf(user1);

        // Stake tokens
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stake(stakeAmount);
        vm.stopPrank();

        // Verify staking worked
        assertEq(axSumr.balanceOf(user1), stakeAmount);
        assertEq(
            aSummerToken.balanceOf(user1),
            initialSummerBalance - stakeAmount
        );

        // Unstake tokens
        vm.startPrank(user1);
        axSumr.approve(address(aStaking), stakeAmount);
        aStaking.unstake(stakeAmount);
        vm.stopPrank();

        // Verify round trip worked
        assertEq(axSumr.balanceOf(user1), 0);
        assertEq(aSummerToken.balanceOf(user1), initialSummerBalance);
    }

    function test_MultipleUsers_StakeSeparately() public {
        // Create fresh staking contract to avoid state interference
        SummerStaking freshStaking = createFreshStaking();

        uint256 stakeAmount1 = STAKE_AMOUNT;
        uint256 stakeAmount2 = STAKE_AMOUNT / 2;

        // User 1 stakes
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount1);
        freshStaking.stake(stakeAmount1);
        vm.stopPrank();

        // User 2 stakes
        vm.startPrank(user2);
        aSummerToken.approve(address(freshStaking), stakeAmount2);
        freshStaking.stake(stakeAmount2);
        vm.stopPrank();

        // Verify both users have correct balances
        assertEq(axSumr.balanceOf(user1), stakeAmount1);
        assertEq(axSumr.balanceOf(user2), stakeAmount2);
        assertEq(
            aSummerToken.balanceOf(address(freshStaking)),
            stakeAmount1 + stakeAmount2
        );
    }

    function test_StakeUnstake_MultipleRounds() public {
        // Create fresh staking contract to avoid state interference
        SummerStaking freshStaking = createFreshStaking();

        uint256 stakeAmount = STAKE_AMOUNT / 4;

        // Stake multiple times
        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(user1);
            aSummerToken.approve(address(freshStaking), stakeAmount);
            freshStaking.stake(stakeAmount);
            vm.stopPrank();
        }

        // Verify accumulated staking
        assertEq(axSumr.balanceOf(user1), stakeAmount * 4);
        assertEq(
            aSummerToken.balanceOf(address(freshStaking)),
            stakeAmount * 4
        );

        // Unstake multiple times
        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(user1);
            axSumr.approve(address(freshStaking), stakeAmount);
            freshStaking.unstake(stakeAmount);
            vm.stopPrank();
        }

        // Verify final balances
        assertEq(axSumr.balanceOf(user1), 0);
        assertEq(aSummerToken.balanceOf(address(freshStaking)), 0);
    }
}
