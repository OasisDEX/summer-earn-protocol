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

// Import the minimal interfaces from Staking contract
interface IMinimalVestingFactory {
    function vestingWallets(address _user) external view returns (address);
    function vestingWalletOwners(
        address _wallet
    ) external view returns (address);
}

interface IMinimalVestingWallet {
    function balanceOf(address _user) external view returns (uint256);
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function released(address _token) external view returns (uint256);
}

/*
 * @title Staking Vesting Tests
 * @dev Test contract for Staking contract vesting functionality.
 */

// Mock Vesting Factory for testing
contract MockVestingFactory is IMinimalVestingFactory {
    mapping(address => address) public vestingWallets;
    mapping(address => address) public vestingWalletOwners;

    function setVestingWallet(address user, address wallet) external {
        address previousOwner = vestingWalletOwners[wallet];
        vestingWallets[previousOwner] = address(0);
        vestingWallets[user] = wallet;
        vestingWalletOwners[wallet] = user;
    }

    function removeVestingWallet(address user) external {
        address wallet = vestingWallets[user];
        if (wallet != address(0)) {
            vestingWalletOwners[wallet] = address(0);
            vestingWallets[user] = address(0);
        }
    }
}

// Mock Vesting Wallet for testing
contract MockVestingWallet is IMinimalVestingWallet {
    address public owner;
    MockERC20 public token;

    constructor(address _owner, address _token) {
        owner = _owner;
        token = MockERC20(_token);
    }

    function balanceOf(address) external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner can transfer");
        owner = newOwner;
    }

    function released(address) external pure returns (uint256) {
        return 0;
    }
}

/*
 * @title Staking Vesting Tests
 * @dev Test contract for Staking contract vesting functionality.
 */
contract StakingVestingTest is SummerGovernorV2TestBase {
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    uint256 public constant STAKE_AMOUNT = 1000 ether;

    MockVestingFactory public mockVestingFactory1;
    MockVestingFactory public mockVestingFactory2;
    MockVestingWallet public mockVestingWallet1;
    MockVestingWallet public mockVestingWallet2;

    Staking public testStaking;

    function setUp() public override {
        super.setUp();

        // Create mock vesting factories and wallets
        mockVestingFactory1 = new MockVestingFactory();
        mockVestingFactory2 = new MockVestingFactory();

        // Create test staking with mock factories first
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(mockVestingFactory1);
        vestingFactories[1] = address(mockVestingFactory2);

        testStaking = new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );

        // Now create vesting wallets with the staking contract address as owner (to skip the transfer ownership step)
        mockVestingWallet1 = new MockVestingWallet(
            address(testStaking),
            address(aSummerToken)
        );
        mockVestingWallet2 = new MockVestingWallet(
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

        // Set staking module so testStaking can mint/burn xSumr
        vm.prank(address(timelockA));
        axSumr.setStakingModule(address(testStaking));

        // Setup test users with tokens
        deal(address(aSummerToken), user1, STAKE_AMOUNT * 2);
        deal(address(aSummerToken), user2, STAKE_AMOUNT * 2);

        // Give vesting wallets some tokens
        deal(address(aSummerToken), address(mockVestingWallet1), STAKE_AMOUNT);
        deal(
            address(aSummerToken),
            address(mockVestingWallet2),
            STAKE_AMOUNT / 2
        );

        vm.label(user1, "user1");
        vm.label(user2, "user2");
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
        uint256 expectedTotal = STAKE_AMOUNT + (STAKE_AMOUNT / 2); // 1000 + 500

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Verify user received xSumr for total vesting balance
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Note: tokens remain in vesting wallets, staking contract doesn't hold them
        assertEq(aSummerToken.balanceOf(address(testStaking)), 0);
    }

    function test_StakeWithVesting_UserHasVestingWallets_Cycle() public {
        // expected total from two vesting wallets
        uint256 expectedTotal = STAKE_AMOUNT + (STAKE_AMOUNT / 2); // 1000 + 500

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Verify user received xSumr for total vesting balance
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Note: tokens remain in vesting wallets, staking contract doesn't hold them
        assertEq(aSummerToken.balanceOf(address(testStaking)), 0);

        uint userSumrBalanceBefore = aSummerToken.balanceOf(user1);
        // Unstake with vesting
        vm.startPrank(user1);
        axSumr.approve(address(testStaking), expectedTotal);
        testStaking.unstakeVesting();
        vm.stopPrank();

        // Verify user received xSumr for total vesting balance
        assertEq(aSummerToken.balanceOf(user1), userSumrBalanceBefore);
        assertEq(MockVestingWallet(mockVestingWallet1).owner(), user1);
        assertEq(MockVestingWallet(mockVestingWallet2).owner(), user1);

        // Note: tokens remain in vesting wallets, staking contract doesn't hold them
        assertEq(aSummerToken.balanceOf(address(testStaking)), 0);
    }

    function test_StakeWithVesting_UserHasVOneVestingWallet() public {
        mockVestingFactory2.removeVestingWallet(user1);
        // expected total from two vesting wallets
        uint256 expectedTotal = STAKE_AMOUNT;

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Verify user received xSumr for total vesting balance
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Note: tokens remain in vesting wallets, staking contract doesn't hold them
        assertEq(aSummerToken.balanceOf(address(testStaking)), 0);
    }
    function test_StakeWithVesting_UserHasNoVestingWallets() public {
        // Remove vesting wallets for user2
        mockVestingFactory1.removeVestingWallet(user2);
        mockVestingFactory2.removeVestingWallet(user2);

        // Attempt to stake with vesting - should revert
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("Staking_VestingWalletsEmpty()")
        );
        testStaking.stakeWithVesting();
    }

    function test_StakeWithVesting_UserHasEmptyVestingWallets() public {
        // Set vesting wallet balances to zero
        deal(address(aSummerToken), address(mockVestingWallet1), 0);
        deal(address(aSummerToken), address(mockVestingWallet2), 0);

        // Stake with vesting
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("Staking_VestingWalletsEmpty()")
        );
        testStaking.stakeWithVesting();

        // Verify user received 0 xSumr (empty vesting wallets)
        assertEq(axSumr.balanceOf(user1), 0);
        // Note: tokens don't actually move to staking contract
    }

    function test_StakeWithVesting_MultipleCalls() public {
        uint256 expectedTotal = STAKE_AMOUNT + (STAKE_AMOUNT / 2);

        // First call
        vm.prank(user1);
        testStaking.stakeWithVesting();

        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Second call should revert because the user has already staked from this vesting factory
        vm.expectRevert(
            abi.encodeWithSignature("Staking_VestingWalletsEmpty()")
        );
        vm.prank(user1);
        testStaking.stakeWithVesting();

        assertEq(axSumr.balanceOf(user1), expectedTotal);
        // Note: tokens don't actually move to staking contract
    }

    function test_UnstakeVesting_UserHasNoVestingWallets() public {
        // Remove vesting wallets for user2
        mockVestingFactory1.removeVestingWallet(user2);
        mockVestingFactory2.removeVestingWallet(user2);

        // Attempt to unstake vesting - should revert
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("Staking_NoVestingWalletsStaked()")
        );
        testStaking.unstakeVesting();
    }

    function test_StakeWithVesting_VestingWalletNotOwnedByStaking() public {
        // Change ownership of vesting wallet to someone else
        vm.prank(address(testStaking));
        mockVestingWallet1.transferOwnership(user2);

        // Attempt to stake with vesting - should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking__InvalidOwner(string)",
                "Vesting wallet not owned by staking"
            )
        );
        testStaking.stakeWithVesting();
    }

    function test_UnstakeVesting_VestingWalletNotOwnedByStaking() public {
        // First stake
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Change ownership of vesting wallet to someone else
        vm.prank(address(testStaking));
        mockVestingWallet1.transferOwnership(user2);

        // Attempt to unstake vesting - should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking__InvalidOwner(string)",
                "Vesting wallet not owned by staking"
            )
        );
        testStaking.unstakeVesting();
    }

    // ========================================
    // VESTING EDGE CASES
    // ========================================

    function test_StakeWithVesting_ReasonableAmounts() public {
        // Give vesting wallets reasonable amounts
        uint256 amount1 = STAKE_AMOUNT * 2;
        uint256 amount2 = STAKE_AMOUNT * 3;
        deal(address(aSummerToken), address(mockVestingWallet1), amount1);
        deal(address(aSummerToken), address(mockVestingWallet2), amount2);

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Verify user received xSumr for the amounts
        assertEq(axSumr.balanceOf(user1), amount1 + amount2);
        // Note: tokens don't actually move from vesting wallets to staking contract
        // The staking contract just checks ownership and mints xSumr
    }

    // ========================================
    // EDGE CASES AND ERROR CONDITIONS
    // ========================================

    function test_StakeWithVesting_ZeroAddressFactory() public {
        // Create staking with a zero address factory (edge case)
        address[] memory vestingFactories = new address[](1);
        vestingFactories[0] = address(0);

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

    function test_StakeWithVesting_MixedOwnedAndUnownedWallets() public {
        // Setup: wallet1 owned by staking, wallet2 owned by someone else
        vm.prank(address(testStaking));
        mockVestingWallet2.transferOwnership(user2); // Change ownership

        // Attempt to stake - should revert due to unowned wallet
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking__InvalidOwner(string)",
                "Vesting wallet not owned by staking"
            )
        );
        testStaking.stakeWithVesting();
    }

    function test_UnstakeVesting_MixedOwnedAndUnownedWallets() public {
        // First stake
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // First stake with mixed ownership (this should fail)
        vm.prank(address(testStaking));
        mockVestingWallet2.transferOwnership(user2);

        // Attempt to unstake - should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking__InvalidOwner(string)",
                "Vesting wallet not owned by staking"
            )
        );
        testStaking.unstakeVesting();
    }

    // ========================================
    // COMPREHENSIVE VESTING STAKING TESTS
    // ========================================

    function test_StakeWithVesting_ValidateVestingFactoryMappings() public {
        // Test that staking properly validates vesting factory mappings
        uint256 expectedTotal = STAKE_AMOUNT + (STAKE_AMOUNT / 2);

        // Verify initial ownership
        assertEq(
            MockVestingWallet(mockVestingWallet1).owner(),
            address(testStaking)
        );
        assertEq(
            MockVestingWallet(mockVestingWallet2).owner(),
            address(testStaking)
        );

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Verify user received xSumr for total vesting balance
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
            STAKE_AMOUNT * 2
        );

        // User1 stakes
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // User2 stakes from same factory
        vm.prank(user2);
        testStaking.stakeWithVesting();

        // Both should have received xSumr
        assertEq(
            axSumr.balanceOf(user1),
            STAKE_AMOUNT / 2,
            "User1 should have received xSumr"
        );
        assertEq(
            axSumr.balanceOf(user2),
            STAKE_AMOUNT * 2,
            "User2 should have received xSumr"
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
    }

    function test_UnstakeVesting_ValidateBurnAmounts() public {
        uint256 expectedTotal = STAKE_AMOUNT + (STAKE_AMOUNT / 2);

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();
        assertEq(axSumr.balanceOf(user1), expectedTotal);

        // Record balances before unstaking
        uint256 stakingXSumrBefore = axSumr.balanceOf(address(testStaking));

        // Unstake with vesting
        vm.startPrank(user1);
        axSumr.approve(address(testStaking), expectedTotal);
        testStaking.unstakeVesting();
        vm.stopPrank();

        // Verify xSumr was burned from user and staking contract has no xSumr
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
        testStaking.stakeWithVesting();

        // Verify user received xSumr for large amounts
        assertEq(axSumr.balanceOf(user1), largeAmount1 + largeAmount2);
    }

    function test_UnstakeVesting_AfterTokenTransfer() public {
        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Transfer some xSumr to another user
        vm.prank(user1);
        axSumr.transfer(user2, STAKE_AMOUNT / 4);

        // Should not be able to unstake remaining amount
        uint256 remainingAmount = STAKE_AMOUNT +
            (STAKE_AMOUNT / 2) -
            (STAKE_AMOUNT / 4);

        vm.startPrank(user1);
        axSumr.approve(address(testStaking), 4 * remainingAmount);
        vm.expectRevert();
        testStaking.unstakeVesting();
        vm.stopPrank();

        // User1 should have remaining amount left, user2 should still have the transferred amount
        assertEq(axSumr.balanceOf(user1), remainingAmount);
        assertEq(axSumr.balanceOf(user2), STAKE_AMOUNT / 4);
    }

    function test_StakeWithVesting_ZeroBalanceAfterPartialTransfer() public {
        // Set very small balance for one wallet
        deal(address(aSummerToken), address(mockVestingWallet2), 1);

        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Should receive xSumr for the non-zero balance wallet only
        assertEq(axSumr.balanceOf(user1), STAKE_AMOUNT + 1);
    }

    function test_UnstakeVesting_ValidateOwnershipTransferBack() public {
        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Verify current ownership
        assertEq(
            MockVestingWallet(mockVestingWallet1).owner(),
            address(testStaking)
        );
        assertEq(
            MockVestingWallet(mockVestingWallet2).owner(),
            address(testStaking)
        );

        // Unstake with vesting
        vm.startPrank(user1);
        axSumr.approve(address(testStaking), STAKE_AMOUNT + (STAKE_AMOUNT / 2));
        testStaking.unstakeVesting();
        vm.stopPrank();

        // Verify ownership transferred back to user
        assertEq(MockVestingWallet(mockVestingWallet1).owner(), user1);
        assertEq(MockVestingWallet(mockVestingWallet2).owner(), user1);
    }

    function test_StakeWithVesting_AlreadyStaked() public {
        // First stake
        vm.prank(user1);
        testStaking.stakeWithVesting();
        uint256 firstStakeAmount = axSumr.balanceOf(user1);

        // Try to stake again - should revert
        vm.expectRevert(
            abi.encodeWithSignature("Staking_VestingWalletsEmpty()")
        );
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Balance should remain the same
        assertEq(axSumr.balanceOf(user1), firstStakeAmount);
    }

    function test_UnstakeVesting_WithoutPriorStaking() public {
        // Try to unstake without staking first
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("Staking_NoVestingWalletsStaked()")
        );
        testStaking.unstakeVesting();
    }

    function test_StakeWithVesting_FactoryRemoved() public {
        // Remove one factory
        vm.prank(address(timelockA));
        testStaking.removeVestingFactory(address(mockVestingFactory2));

        // Stake with vesting - should only stake from remaining factory
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Should only receive xSumr for the wallet from the remaining factory
        assertEq(axSumr.balanceOf(user1), STAKE_AMOUNT);
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
            abi.encodeWithSignature("Staking_VestingWalletsEmpty()")
        );
        testStaking.stakeWithVesting();
    }

    function test_UnstakeVesting_AfterFactoryRemoved() public {
        // Stake with vesting
        vm.prank(user1);
        testStaking.stakeWithVesting();

        // Remove one factory
        vm.prank(address(timelockA));
        testStaking.removeVestingFactory(address(mockVestingFactory2));

        // Should still be able to unstake from remaining factory
        vm.startPrank(user1);
        axSumr.approve(address(testStaking), STAKE_AMOUNT + (STAKE_AMOUNT / 2));
        testStaking.unstakeVesting();
        vm.stopPrank();

        // Verify ownership transferred back
        assertEq(MockVestingWallet(mockVestingWallet1).owner(), user1);
        assertEq(MockVestingWallet(mockVestingWallet2).owner(), user1);
    }

    function test_StakeWithVesting_ConcurrentUsers() public {
        // give second user factory #1 wallet of user1
        mockVestingFactory2.setVestingWallet(
            user2,
            address(mockVestingWallet2)
        );
        // Setup third user
        address user3 = address(0x1003);
        MockVestingWallet mockVestingWallet3 = new MockVestingWallet(
            address(testStaking),
            address(aSummerToken)
        );
        mockVestingFactory1.setVestingWallet(
            user3,
            address(mockVestingWallet3)
        );
        deal(address(aSummerToken), address(mockVestingWallet3), STAKE_AMOUNT);

        // All users stake concurrently
        vm.prank(user1);
        testStaking.stakeWithVesting();

        vm.prank(user2);
        testStaking.stakeWithVesting();

        vm.prank(user3);
        testStaking.stakeWithVesting();

        // All should have received xSumr
        assertEq(axSumr.balanceOf(user1), STAKE_AMOUNT);
        assertEq(axSumr.balanceOf(user2), STAKE_AMOUNT / 2);
        assertEq(axSumr.balanceOf(user3), STAKE_AMOUNT);
    }
}
