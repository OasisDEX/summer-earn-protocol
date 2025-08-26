// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Staking} from "../../src/contracts/Staking.sol";
import {ISummerGovernorV2} from "../../src/interfaces/ISummerGovernorV2.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {xSumr} from "../../src/contracts/xSumr.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ExposedSummerGovernor, SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/*
 * @title Staking Core Tests
 * @dev Test contract for Staking contract constructor and core functionality.
 */
contract StakingCoreTest is SummerGovernorV2TestBase {
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    uint256 public constant STAKE_AMOUNT = 1000 ether;

    function setUp() public override {
        super.setUp();

        // Setup test users with tokens
        deal(address(aSummerToken), user1, STAKE_AMOUNT * 2);
        deal(address(aSummerToken), user2, STAKE_AMOUNT * 2);
    }

    // Helper function to create a fresh staking contract for isolated tests
    function createFreshStaking() internal returns (Staking) {
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        Staking freshStaking = new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
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

        Staking newStaking = new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        assertEq(address(newStaking.SUMMER_TOKEN()), address(aSummerToken));
        assertEq(address(newStaking.STAKED_SUMMER_TOKEN()), address(axSumr));
        assertEq(newStaking.vestingFactories().length, 2);
        assertEq(newStaking.getVestingFactory(0), address(factoryVestingV2));
        assertEq(newStaking.getVestingFactory(1), address(factoryVesting));
    }

    function test_Constructor_ZeroProtocolAccessManager() public {
        address[] memory vestingFactories = new address[](0);

        vm.expectRevert(); // Should revert due to ProtocolAccessManaged constructor
        new Staking(
            address(0), // Zero protocol access manager
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );
    }

    function test_Constructor_ZeroSummerToken() public {
        address[] memory vestingFactories = new address[](0);

        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Summer token address cannot be zero"
            )
        );
        new Staking(
            address(accessManagerA),
            address(0), // Zero summer token
            address(axSumr),
            vestingFactories
        );
    }

    function test_Constructor_ZeroXSumr() public {
        address[] memory vestingFactories = new address[](0);

        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "xSumr address cannot be zero"
            )
        );
        new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(0), // Zero xSumr
            vestingFactories
        );
    }

    function test_Constructor_ZeroVestingFactoryAddress() public {
        address[] memory vestingFactories = new address[](1);
        vestingFactories[0] = address(0); // Zero address in array

        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Vesting factory address cannot be zero"
            )
        );
        new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );
    }

    function test_Constructor_EmptyVestingFactories() public {
        address[] memory vestingFactories = new address[](0);

        Staking newStaking = new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        assertEq(newStaking.vestingFactories().length, 0);
    }

    function test_Constructor_SingleVestingFactory() public {
        address[] memory vestingFactories = new address[](1);
        vestingFactories[0] = address(factoryVestingV2);

        Staking newStaking = new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        assertEq(newStaking.vestingFactories().length, 1);
        assertEq(newStaking.getVestingFactory(0), address(factoryVestingV2));
    }

    function test_Constructor_MultipleVestingFactories() public {
        address[] memory vestingFactories = new address[](3);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);
        vestingFactories[2] = address(0x1234); // Mock address

        Staking newStaking = new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        assertEq(newStaking.vestingFactories().length, 3);
        for (uint256 i = 0; i < vestingFactories.length; i++) {
            assertEq(newStaking.getVestingFactory(i), vestingFactories[i]);
        }
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
        Staking freshStaking = createFreshStaking();

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
        Staking freshStaking = createFreshStaking();

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
