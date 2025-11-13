// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerVestingWalletsEscrow} from "../../src/contracts/SummerVestingWalletsEscrow.sol";
import {StakedSummerToken} from "../../src/contracts/StakedSummerToken.sol";

import {Test} from "forge-std/Test.sol";
import {SummerVestingWalletsEscrowTestBase} from "./SummerVestingWalletsEscrowTestBase.sol";
import {ISummerVestingWalletsEscrow} from "../../src/interfaces/ISummerVestingWalletsEscrow.sol";
import {TestMockVestingFactory} from "../mocks/MockVestingFactory.sol";
import {TestMockVestingWallet} from "../mocks/MockVestingFactory.sol";

/*
 * @title SummerVestingWalletsEscrow Vesting Tests
 * @dev Test contract for SummerVestingWalletsEscrow contract vesting functionality.
 */
contract StakingVestingTest is SummerVestingWalletsEscrowTestBase {
    TestMockVestingFactory public mockVestingFactory1;
    TestMockVestingFactory public mockVestingFactory2;
    TestMockVestingWallet public mockVestingWallet1;
    TestMockVestingWallet public mockVestingWallet2;

    SummerVestingWalletsEscrow public testStaking;
    address[] public mockVestingFactories;
    address[] public onlyFirstFactory;
    address[] public onlySecondFactory;

    function setUp() public override {
        super.setUp();

        // Create mock vesting factories and wallets
        mockVestingFactory1 = new TestMockVestingFactory();
        mockVestingFactory2 = new TestMockVestingFactory();

        // Create test staking with mock factories first
        mockVestingFactories = new address[](2);
        mockVestingFactories[0] = address(mockVestingFactory1);
        mockVestingFactories[1] = address(mockVestingFactory2);
        onlyFirstFactory = new address[](1);
        onlyFirstFactory[0] = address(mockVestingFactory1);
        onlySecondFactory = new address[](1);
        onlySecondFactory[0] = address(mockVestingFactory2);

        testStaking = new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            mockVestingFactories
        );

        // Now create vesting wallets with the staking contract address as owner (to skip the transfer ownership step)
        mockVestingWallet1 = new TestMockVestingWallet(
            address(testStaking),
            address(aSummerToken)
        );
        mockVestingWallet2 = new TestMockVestingWallet(
            address(testStaking),
            address(aSummerToken)
        );

        // Setup vesting factories with wallets for users (so initially staking is new owner, user is original owner)
        mockVestingFactory1.setVestingWallet(
            user1,
            address(mockVestingWallet1)
        );
        mockVestingFactory2.setVestingWallet(
            user1,
            address(mockVestingWallet2)
        );

        // Set staking module so testStaking can mint/burn StakedSummerToken
        vm.prank(address(timelockA));
        axSumr.addStakingModule(address(testStaking));

        // Setup test users with tokens
        deal(address(aSummerToken), user1, VESTING_AMOUNT_WALLET_1 * 2);
        deal(address(aSummerToken), user2, VESTING_AMOUNT_WALLET_1 * 2);

        // Give vesting wallets some tokens
        deal(
            address(aSummerToken),
            address(mockVestingWallet1),
            VESTING_AMOUNT_WALLET_1
        );
        deal(
            address(aSummerToken),
            address(mockVestingWallet2),
            VESTING_AMOUNT_WALLET_2
        );

        vm.label(address(mockVestingWallet1), "mockVestingWallet1");
        vm.label(address(mockVestingWallet2), "mockVestingWallet2");
        vm.label(address(mockVestingFactory1), "mockVestingFactory1");
        vm.label(address(mockVestingFactory2), "mockVestingFactory2");
        vm.label(address(testStaking), "testStaking");
    }

    // ========================================
    // VESTING STAKING TESTS
    // ========================================

    function test_StakeWithVesting_UserHasVestingWallets() public {
        // expected total from two vesting wallets
        uint256 expectedTotal = VESTING_AMOUNT_WALLET_1 +
            VESTING_AMOUNT_WALLET_2; // 1000 + 500

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Verify user received StakedSummerToken for total vesting balance
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Note: tokens remain in vesting wallets, staking contract doesn't hold them
        assertEq(aSummerToken.balanceOf(address(testStaking)), 0);
    }

    function test_StakeWithVesting_UserHasVestingWallets_Cycle() public {
        // expected total from two vesting wallets
        uint256 expectedTotal = VESTING_AMOUNT_WALLET_1 +
            VESTING_AMOUNT_WALLET_2; // 1000 + 500

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Verify user received StakedSummerToken for total vesting balance
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Note: tokens remain in vesting wallets, staking contract doesn't hold them
        assertEq(aSummerToken.balanceOf(address(testStaking)), 0);

        uint userSumrBalanceBefore = aSummerToken.balanceOf(user1);
        // Unstake with vesting
        vm.startPrank(user1);
        axSumr.approve(address(testStaking), expectedTotal);
        testStaking.unstakeVesting(mockVestingFactories);
        vm.stopPrank();

        // Verify user received StakedSummerToken for total vesting balance
        assertEq(aSummerToken.balanceOf(user1), userSumrBalanceBefore);
        assertEq(TestMockVestingWallet(mockVestingWallet1).owner(), user1);
        assertEq(TestMockVestingWallet(mockVestingWallet2).owner(), user1);

        // Note: tokens remain in vesting wallets, staking contract doesn't hold them
        assertEq(aSummerToken.balanceOf(address(testStaking)), 0);
    }

    function test_StakeWithVesting_UserHasOneVestingWallet() public {
        mockVestingFactory2.removeVestingWallet(user1);
        // expected total from two vesting wallets
        uint256 expectedTotal = VESTING_AMOUNT_WALLET_1;

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(onlyFirstFactory);

        // Verify user received StakedSummerToken for total vesting balance
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Note: tokens remain in vesting wallets, staking contract doesn't hold them
        assertEq(aSummerToken.balanceOf(address(testStaking)), 0);
    }
    function test_StakeWithVesting_UserHasNoVestingWallets() public {
        // Attempt to stake with empty vesting wallets - should revert
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletsEscrow.Staking_InvalidAddress.selector,
                "Vesting wallet not found"
            )
        );
        testStaking.stakeVesting(mockVestingFactories);
    }

    function test_StakeWithVesting_UserHasEmptyVestingWallets() public {
        // Set vesting wallet balances to zero
        deal(address(aSummerToken), address(mockVestingWallet1), 0);
        deal(address(aSummerToken), address(mockVestingWallet2), 0);

        // Stake with vesting
        vm.prank(user1);
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_ZeroBalance.selector
        );
        testStaking.stakeVesting(mockVestingFactories);

        // Verify user received 0 StakedSummerToken (empty vesting wallets)
        assertEq(axSumr.balanceOf(user1), 0);
        // Note: tokens don't actually move to staking contract
    }

    function test_UnstakeVesting_UserHasNoVestingWallets() public {
        // Attempt to unstake vesting - should revert
        vm.prank(user2);
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_NoStakeForFactory.selector
        );
        testStaking.unstakeVesting(mockVestingFactories);
    }

    function test_StakeWithVesting_VestingWalletNotOwnedByStaking() public {
        // Change ownership of vesting wallet to someone else
        vm.prank(address(testStaking));
        mockVestingWallet1.transferOwnership(user2);

        // Attempt to stake with vesting - should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletsEscrow.Staking_InvalidOwner.selector,
                "Vesting wallet not owned by escrow"
            )
        );
        testStaking.stakeVesting(mockVestingFactories);
    }

    function test_UnstakeVesting_VestingWalletNotOwnedByStaking() public {
        // First stake
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Change ownership of vesting wallet to someone else
        vm.prank(address(testStaking));
        mockVestingWallet1.transferOwnership(user2);

        // Attempt to unstake vesting - should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletsEscrow.Staking_InvalidOwner.selector,
                "Vesting wallet not owned by escrow"
            )
        );
        testStaking.unstakeVesting(mockVestingFactories);
    }

    // ========================================
    // VESTING EDGE CASES
    // ========================================

    function test_StakeWithVesting_ReasonableAmounts() public {
        // Give vesting wallets reasonable amounts
        uint256 amount1 = VESTING_AMOUNT_WALLET_1 * 2;
        uint256 amount2 = VESTING_AMOUNT_WALLET_1 * 3;
        deal(address(aSummerToken), address(mockVestingWallet1), amount1);
        deal(address(aSummerToken), address(mockVestingWallet2), amount2);

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Verify user received StakedSummerToken for the amounts
        assertEq(axSumr.balanceOf(user1), amount1 + amount2);
        // Note: tokens don't actually move from vesting wallets to staking contract
        // The staking contract just checks ownership and mints StakedSummerToken
    }

    // ========================================
    // EDGE CASES AND ERROR CONDITIONS
    // ========================================

    function test_StakeWithVesting_MixedOwnedAndUnownedWallets() public {
        // Setup: wallet1 owned by staking, wallet2 owned by someone else
        vm.prank(address(testStaking));
        mockVestingWallet2.transferOwnership(user2); // Change ownership

        // Attempt to stake - should revert due to unowned wallet
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidOwner(string)",
                "Vesting wallet not owned by escrow"
            )
        );
        testStaking.stakeVesting(mockVestingFactories);
    }

    function test_UnstakeVesting_MixedOwnedAndUnownedWallets() public {
        // First stake
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Transfer ownership of second wallet to someone else ( quite impossible situation)
        vm.prank(address(testStaking));
        mockVestingWallet2.transferOwnership(user2);

        // Attempt to unstake - should revert
        vm.startPrank(user1);
        axSumr.approve(
            address(testStaking),
            VESTING_AMOUNT_WALLET_1 + VESTING_AMOUNT_WALLET_2
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletsEscrow.Staking_InvalidOwner.selector,
                "Vesting wallet not owned by escrow"
            )
        );
        testStaking.unstakeVesting(mockVestingFactories);
    }

    // ========================================
    // COMPREHENSIVE VESTING STAKING TESTS
    // ========================================

    function test_StakeWithVesting_ValidateVestingFactoryMappings() public {
        // Test that staking properly validates vesting factory mappings
        uint256 expectedTotal = VESTING_AMOUNT_WALLET_1 +
            (VESTING_AMOUNT_WALLET_2);

        // Verify initial ownership
        assertEq(
            TestMockVestingWallet(mockVestingWallet1).owner(),
            address(testStaking)
        );
        assertEq(
            TestMockVestingWallet(mockVestingWallet2).owner(),
            address(testStaking)
        );

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Verify user received StakedSummerToken for total vesting balance
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Verify factory mappings are still correct
        assertEq(
            mockVestingFactory1.vestingWallets(user1),
            address(mockVestingWallet1)
        );
        assertEq(
            mockVestingFactory2.vestingWallets(user1),
            address(mockVestingWallet2)
        );
        assertEq(
            mockVestingFactory1.vestingWalletOwners(
                address(mockVestingWallet1)
            ),
            user1
        );
        assertEq(
            mockVestingFactory2.vestingWalletOwners(
                address(mockVestingWallet2)
            ),
            user1
        );
    }

    function test_StakeWithVesting_SingleFactoryMultipleUsers() public {
        // Setup second user
        mockVestingFactory1.setVestingWallet(
            user2,
            address(mockVestingWallet1)
        );
        deal(
            address(aSummerToken),
            address(mockVestingWallet1),
            VESTING_AMOUNT_WALLET_1 * 2
        );

        // User1 stakes
        vm.prank(user1);
        testStaking.stakeVesting(onlySecondFactory);

        // User2 stakes from same factory
        vm.prank(user2);
        testStaking.stakeVesting(onlyFirstFactory);

        // Both should have received StakedSummerToken
        assertEq(
            axSumr.balanceOf(user1),
            VESTING_AMOUNT_WALLET_2,
            "User1 should have received StakedSummerToken"
        );
        assertEq(
            axSumr.balanceOf(user2),
            VESTING_AMOUNT_WALLET_1 * 2,
            "User2 should have received StakedSummerToken"
        );
        assertEq(
            testStaking.userStakedVestingFactories(user1).length,
            1,
            "User1 should have 1 staked vesting factory"
        );
        assertEq(
            testStaking.userStakedVestingFactories(user2).length,
            1,
            "User2 should have 1 staked vesting factory"
        );
        assertEq(
            testStaking.userStakedVestingFactories(user1)[0],
            address(mockVestingFactory2),
            "User1 should have factory 2 in staked vesting factories"
        );
        assertEq(
            testStaking.userStakedVestingFactories(user2)[0],
            address(mockVestingFactory1),
            "User2 should have factory 1 in staked vesting factories"
        );
        assertEq(
            testStaking.getUserStakedVestingFactory(user1, 0),
            address(mockVestingFactory2),
            "User1 should have factory 2 in staked vesting factories"
        );
        assertEq(
            testStaking.getUserStakedVestingFactory(user2, 0),
            address(mockVestingFactory1),
            "User2 should have factory 1 in staked vesting factories"
        );
    }

    function test_UnstakeVesting_ValidateBurnAmounts() public {
        uint256 expectedTotal = VESTING_AMOUNT_WALLET_1 +
            (VESTING_AMOUNT_WALLET_2);

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Record balances before unstaking
        uint256 stakingXSumrBefore = axSumr.balanceOf(address(testStaking));

        // Unstake with vesting
        vm.startPrank(user1);
        axSumr.approve(address(testStaking), expectedTotal);
        testStaking.unstakeVesting(mockVestingFactories);
        vm.stopPrank();

        // Verify StakedSummerToken was burned from user and staking contract has no StakedSummerToken
        assertEq(axSumr.balanceOf(user1), 0);
        assertEq(axSumr.balanceOf(address(testStaking)), stakingXSumrBefore);
    }

    function test_StakeWithVesting_LargeAmounts() public {
        // Test with very large amounts
        uint256 largeAmount1 = 1000000 * 10 ** 18; // 1M tokens
        uint256 largeAmount2 = 2000000 * 10 ** 18; // 2M tokens

        deal(address(aSummerToken), address(mockVestingWallet1), largeAmount1);
        deal(address(aSummerToken), address(mockVestingWallet2), largeAmount2);

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Verify user received StakedSummerToken for large amounts
        assertEq(axSumr.balanceOf(user1), largeAmount1 + largeAmount2);
    }

    function test_UnstakeVesting_AfterTokenBurn() public {
        uint256 burnAmount = VESTING_AMOUNT_WALLET_1 / 4;
        uint256 totalVestedAmount = VESTING_AMOUNT_WALLET_1 +
            VESTING_AMOUNT_WALLET_2;
        uint amountLeftOnSecondWalletUnstake = totalVestedAmount -
            VESTING_AMOUNT_WALLET_1 -
            burnAmount;
        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Burn some StakedSummerToken
        vm.prank(user1);
        axSumr.burn(burnAmount);

        // Should not be able to unstake remaining amount
        uint256 remainingAmount = totalVestedAmount - (burnAmount);

        vm.startPrank(user1);
        axSumr.approve(address(testStaking), totalVestedAmount);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                user1,
                amountLeftOnSecondWalletUnstake,
                VESTING_AMOUNT_WALLET_2
            )
        );
        testStaking.unstakeVesting(mockVestingFactories);
        vm.stopPrank();

        // User1 should have remaining amount left
        assertEq(
            axSumr.balanceOf(user1),
            remainingAmount,
            "user1 should have remaining amount left"
        );
    }

    function test_StakeWithVesting_ZeroBalanceAfterPartialTransfer() public {
        // Set very small balance for one wallet
        deal(address(aSummerToken), address(mockVestingWallet2), 1);

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Should receive StakedSummerToken for the non-zero balance wallet only
        assertEq(
            axSumr.balanceOf(user1),
            VESTING_AMOUNT_WALLET_1 + 1,
            "user1 should have VESTING_AMOUNT_WALLET_1 + 1 StakedSummerToken"
        );
    }

    function test_UnstakeVesting_ValidateOwnershipTransferBack() public {
        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Verify current ownership
        assertEq(
            TestMockVestingWallet(mockVestingWallet1).owner(),
            address(testStaking)
        );
        assertEq(
            TestMockVestingWallet(mockVestingWallet2).owner(),
            address(testStaking)
        );

        // Unstake with vesting
        vm.startPrank(user1);
        axSumr.approve(
            address(testStaking),
            VESTING_AMOUNT_WALLET_1 + (VESTING_AMOUNT_WALLET_2)
        );
        testStaking.unstakeVesting(mockVestingFactories);
        vm.stopPrank();

        // Verify ownership transferred back to user
        assertEq(TestMockVestingWallet(mockVestingWallet1).owner(), user1);
        assertEq(TestMockVestingWallet(mockVestingWallet2).owner(), user1);
    }

    function test_StakeWithVesting_AlreadyStaked() public {
        // First stake
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);
        uint256 firstStakeAmount = axSumr.balanceOf(user1);

        // Try to stake again - should revert
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_FactoryAlreadyStaked.selector
        );
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Balance should remain the same
        assertEq(axSumr.balanceOf(user1), firstStakeAmount);
    }

    function test_StakeWithVesting_FactoryRemoved() public {
        // Remove one factory
        vm.prank(address(timelockA));
        testStaking.removeVestingFactory(address(mockVestingFactory2));

        // Stake with vesting - should revert due to factory not being enabled
        vm.prank(user1);
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_FactoryNotEnabled.selector
        );
        testStaking.stakeVesting(mockVestingFactories);
    }

    function test_StakeWithVesting_AllFactoriesRemoved() public {
        // Remove both factories
        vm.startPrank(address(timelockA));
        testStaking.removeVestingFactory(address(mockVestingFactory1));
        testStaking.removeVestingFactory(address(mockVestingFactory2));
        vm.stopPrank();

        // Stake with vesting - should revert due to no factories
        vm.prank(user1);
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_FactoryNotEnabled.selector
        );
        testStaking.stakeVesting(mockVestingFactories);
    }

    function test_UnstakeVesting_AfterFactoryRemoved() public {
        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeVesting(mockVestingFactories);

        // Remove one factory
        vm.prank(address(timelockA));
        testStaking.removeVestingFactory(address(mockVestingFactory2));

        // Should still be able to unstake from remaining factory
        vm.startPrank(user1);
        axSumr.approve(
            address(testStaking),
            VESTING_AMOUNT_WALLET_1 + (VESTING_AMOUNT_WALLET_2)
        );
        testStaking.unstakeVesting(mockVestingFactories);
        vm.stopPrank();

        // Verify ownership transferred back
        assertEq(TestMockVestingWallet(mockVestingWallet1).owner(), user1);
        assertEq(TestMockVestingWallet(mockVestingWallet2).owner(), user1);
    }

    function test_StakeWithVesting_ConcurrentUsers() public {
        // give second user factory #1 wallet of user1
        mockVestingFactory2.setVestingWallet(
            user2,
            address(mockVestingWallet2)
        );
        // Setup third user
        address user3 = address(0x1003);
        TestMockVestingWallet mockVestingWallet3 = new TestMockVestingWallet(
            address(testStaking),
            address(aSummerToken)
        );
        mockVestingFactory1.setVestingWallet(
            user3,
            address(mockVestingWallet3)
        );
        deal(
            address(aSummerToken),
            address(mockVestingWallet3),
            VESTING_AMOUNT_WALLET_1
        );

        // All users stake concurrently
        vm.prank(user1);
        testStaking.stakeVesting(onlyFirstFactory);

        vm.prank(user2);
        testStaking.stakeVesting(onlySecondFactory);

        vm.prank(user3);
        testStaking.stakeVesting(onlyFirstFactory);

        // All should have received StakedSummerToken
        assertEq(axSumr.balanceOf(user1), VESTING_AMOUNT_WALLET_1);
        assertEq(axSumr.balanceOf(user2), VESTING_AMOUNT_WALLET_2);
        assertEq(axSumr.balanceOf(user3), VESTING_AMOUNT_WALLET_1);
    }
}
