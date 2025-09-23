// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerVestingWalletsEscrow} from "../../src/interfaces/ISummerVestingWalletsEscrow.sol";

import {SummerVestingWalletsEscrowTestBase} from "./SummerVestingWalletsEscrowTestBase.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

/*
 * @title SummerVestingWalletsEscrow Management Tests
 * @dev Test contract for SummerVestingWalletsEscrow contract management methods.
 */
contract StakingManagementTest is SummerVestingWalletsEscrowTestBase {
    address public newVestingFactory1 = address(0x1001);
    address public newVestingFactory2 = address(0x1002);

    function test_GetVestingFactoryCount_InitialState() public view {
        // Initially should have 2 vesting factories from setup
        assertEq(
            aStaking.vestingFactories().length,
            2,
            "Should have 2 vesting factories initially"
        );
    }

    function test_GetVestingFactory_ValidIndices() public view {
        // Test getting factories at valid indices
        address factory1 = aStaking.getVestingFactory(0);
        address factory2 = aStaking.getVestingFactory(1);

        // Should match the factories set in constructor
        assertTrue(
            factory1 == address(factoryVestingV2) ||
                factory1 == address(factoryVesting),
            "Factory at index 0 should be one of the initial factories"
        );
        assertTrue(
            factory2 == address(factoryVestingV2) ||
                factory2 == address(factoryVesting),
            "Factory at index 1 should be one of the initial factories"
        );
        assertTrue(
            factory1 != factory2,
            "Factories at different indices should be different"
        );
    }

    function test_GetVestingFactory_InvalidIndex() public {
        // Test getting factory at invalid index
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_InvalidIndex.selector
        );
        aStaking.getVestingFactory(2); // Only 2 factories, index 2 is out of bounds

        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_InvalidIndex.selector
        );
        aStaking.getVestingFactory(10); // Way out of bounds
    }

    function test_AddVestingFactory_ValidFactory() public {
        // Add a new vesting factory
        vm.prank(address(timelockA)); // Only governor can add
        vm.expectEmit(true, false, false, false);
        emit ISummerVestingWalletsEscrow.VestingFactoryAdded(
            newVestingFactory1
        );
        aStaking.addVestingFactory(newVestingFactory1);

        // Check count increased
        assertEq(
            aStaking.vestingFactories().length,
            3,
            "Should have 3 vesting factories after adding one"
        );

        // Check factory was added at the end
        address addedFactory = aStaking.getVestingFactory(2);
        assertEq(
            addedFactory,
            newVestingFactory1,
            "New factory should be at index 2"
        );
    }

    function test_AddVestingFactory_ZeroAddress() public {
        // Try to add zero address - should revert
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletsEscrow.Staking_InvalidAddress.selector,
                "Vesting factory address cannot be zero"
            )
        );
        aStaking.addVestingFactory(address(0));
    }

    function test_AddVestingFactory_DuplicateFactory() public {
        // Add factory once
        vm.prank(address(timelockA));
        aStaking.addVestingFactory(newVestingFactory1);

        // Try to add same factory again - should revert
        vm.prank(address(timelockA));
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_DuplicateFactory.selector
        );
        aStaking.addVestingFactory(newVestingFactory1);
    }

    function test_AddVestingFactory_AccessControl() public {
        // Try to add factory without governor role - should revert
        vm.prank(alice); // Alice is not governor
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                alice
            )
        );
        aStaking.addVestingFactory(newVestingFactory1);
    }

    function test_RemoveVestingFactory_ValidFactory() public {
        // First add a factory to remove
        vm.prank(address(timelockA));
        aStaking.addVestingFactory(newVestingFactory1);

        uint256 initialCount = aStaking.vestingFactories().length;
        assertEq(initialCount, 3, "Should have 3 factories before removal");

        // Remove the factory
        vm.prank(address(timelockA));
        vm.expectEmit(true, false, false, false);
        emit ISummerVestingWalletsEscrow.VestingFactoryRemoved(
            newVestingFactory1
        );
        aStaking.removeVestingFactory(newVestingFactory1);

        // Check count decreased
        assertEq(
            aStaking.vestingFactories().length,
            2,
            "Should have 2 vesting factories after removal"
        );

        // Check factory is no longer in the list
        address factory0 = aStaking.getVestingFactory(0);
        address factory1 = aStaking.getVestingFactory(1);

        assertTrue(
            factory0 != newVestingFactory1 && factory1 != newVestingFactory1,
            "Removed factory should not be in the list"
        );
    }

    function test_RemoveVestingFactory_ZeroAddress() public {
        // Try to remove zero address - should revert
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletsEscrow.Staking_InvalidAddress.selector,
                "Vesting factory address cannot be zero"
            )
        );
        aStaking.removeVestingFactory(address(0));
    }

    function test_RemoveVestingFactory_NonExistentFactory() public {
        // Try to remove a factory that doesn't exist - should revert
        vm.prank(address(timelockA));
        vm.expectRevert(
            ISummerVestingWalletsEscrow.Staking_FactoryNotFound.selector
        );
        aStaking.removeVestingFactory(newVestingFactory1); // Never added
    }

    function test_RemoveVestingFactory_AccessControl() public {
        // First add a factory
        vm.prank(address(timelockA));
        aStaking.addVestingFactory(newVestingFactory1);

        // Try to remove without governor role - should revert
        vm.prank(alice); // Alice is not governor
        // Access control revert (non-governor)
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                alice
            )
        );
        aStaking.removeVestingFactory(newVestingFactory1);
    }

    function test_AddRemoveMultipleFactories() public {
        // Add multiple factories
        vm.startPrank(address(timelockA));
        aStaking.addVestingFactory(newVestingFactory1);
        aStaking.addVestingFactory(newVestingFactory2);
        vm.stopPrank();

        // Check count
        assertEq(
            aStaking.vestingFactories().length,
            4,
            "Should have 4 factories after adding 2"
        );

        // Remove one factory
        vm.prank(address(timelockA));
        aStaking.removeVestingFactory(newVestingFactory1);

        // Check count decreased
        assertEq(
            aStaking.vestingFactories().length,
            3,
            "Should have 3 factories after removing 1"
        );

        // Remove another factory
        vm.prank(address(timelockA));
        aStaking.removeVestingFactory(newVestingFactory2);

        // Check final count
        assertEq(
            aStaking.vestingFactories().length,
            2,
            "Should have 2 factories (back to original)"
        );
    }

    function test_VestingFactoryManagement_CompleteWorkflow() public {
        uint256 initialCount = aStaking.vestingFactories().length;

        // Add factories
        vm.startPrank(address(timelockA));
        aStaking.addVestingFactory(newVestingFactory1);
        aStaking.addVestingFactory(newVestingFactory2);
        vm.stopPrank();

        uint256 afterAddCount = aStaking.vestingFactories().length;
        assertEq(
            afterAddCount,
            initialCount + 2,
            "Count should increase by 2 after adding"
        );

        // Verify all factories are accessible
        for (uint256 i = 0; i < afterAddCount; i++) {
            address factory = aStaking.getVestingFactory(i);
            assertTrue(
                factory != address(0),
                "Factory address should not be zero"
            );
        }

        // Remove all added factories
        vm.startPrank(address(timelockA));
        aStaking.removeVestingFactory(newVestingFactory1);
        aStaking.removeVestingFactory(newVestingFactory2);
        vm.stopPrank();

        uint256 finalCount = aStaking.vestingFactories().length;
        assertEq(
            finalCount,
            initialCount,
            "Count should be back to initial after removing added factories"
        );
    }

    function test_GetVestingFactory_AfterRemovals() public {
        // Add a factory
        vm.prank(address(timelockA));
        aStaking.addVestingFactory(newVestingFactory1);

        // Remove an original factory
        vm.prank(address(timelockA));
        aStaking.removeVestingFactory(address(factoryVestingV2));

        // Check that we can still access remaining factories
        uint256 count = aStaking.vestingFactories().length;
        assertEq(count, 2, "Should have 2 factories after add and remove");

        // Verify remaining factories are still accessible
        for (uint256 i = 0; i < count; i++) {
            address factory = aStaking.getVestingFactory(i);
            assertTrue(
                factory != address(0),
                "Remaining factory should not be zero"
            );
            assertTrue(
                factory != address(factoryVestingV2),
                "Removed factory should not be accessible"
            );
        }
    }

    function test_VestingFactoryOperations_EdgeCases() public {
        // Test adding same factory multiple times with different sequences
        vm.startPrank(address(timelockA));

        // Add factory1
        aStaking.addVestingFactory(newVestingFactory1);
        assertEq(aStaking.vestingFactories().length, 3);

        // Try to add factory1 again - should fail
        vm.expectRevert(abi.encodeWithSignature("Staking_DuplicateFactory()"));
        aStaking.addVestingFactory(newVestingFactory1);

        // Add factory2
        aStaking.addVestingFactory(newVestingFactory2);
        assertEq(aStaking.vestingFactories().length, 4);

        // Remove factory1
        aStaking.removeVestingFactory(newVestingFactory1);
        assertEq(aStaking.vestingFactories().length, 3);

        // Now we can add factory1 again
        aStaking.addVestingFactory(newVestingFactory1);
        assertEq(aStaking.vestingFactories().length, 4);

        vm.stopPrank();
    }
}
