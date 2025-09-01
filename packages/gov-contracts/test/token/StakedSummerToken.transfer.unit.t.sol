// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SummerStakingTestBase} from "../staking/SummerStakingTestBase.sol";
import {SummerStaking} from "../../src/contracts/SummerStaking.sol";

contract StakedSummerTokenTransferUnitTest is SummerStakingTestBase {
    address internal burner = address(0xBEEF);
    address internal minter = address(0xA11CE);

    function setUp() public override {
        super.setUp();
    }

    function test_TransfersDisabled_transfer() public {
        uint256 stakeAmount = 10 ether;
        _stake(user1, stakeAmount, 0);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("xSumr__TransfersDisabled()"));
        axSumr.transfer(user2, 1 ether);
    }

    function test_TransfersDisabled_transferFrom() public {
        uint256 stakeAmount = 10 ether;
        _stake(user1, stakeAmount, 0);

        vm.prank(user1);
        axSumr.approve(user2, 1 ether);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSignature("xSumr__TransfersDisabled()"));
        axSumr.transferFrom(user1, user2, 1 ether);
    }

    function test_MintOnlyByMinterRole() public {
        // Non-minter cannot mint
        vm.expectRevert();
        axSumr.mint(user1, 1 ether);

        // Grant MINTER_ROLE via staking module registration
        vm.prank(address(timelockA));
        axSumr.addStakingModule(minter);

        // Minter can mint
        vm.prank(minter);
        axSumr.mint(user1, 5 ether);
        assertEq(axSumr.balanceOf(user1), 5 ether);
    }

    function test_BurnFromOnlyByBurnerRole() public {
        // Prepare balance for user1
        vm.prank(address(timelockA));
        axSumr.addStakingModule(minter);
        vm.prank(minter);
        axSumr.mint(user1, 5 ether);

        // Non-burner cannot burnFrom
        vm.prank(user2);
        vm.expectRevert();
        axSumr.burnFrom(user1, 1 ether);

        // Grant BURNER_ROLE via staking module registration
        vm.prank(address(timelockA));
        axSumr.addStakingModule(burner);

        // Burner can burnFrom
        uint256 supplyBefore = axSumr.totalSupply();
        uint256 balanceBefore = axSumr.balanceOf(user1);
        vm.prank(burner);
        axSumr.burnFrom(user1, 2 ether);
        assertEq(axSumr.totalSupply(), supplyBefore - 2 ether);
        assertEq(axSumr.balanceOf(user1), balanceBefore - 2 ether);
    }

    function test_PauseBlocksMintAndBurn() public {
        // Setup roles and balances
        vm.prank(address(timelockA));
        axSumr.addStakingModule(address(aStaking));

        // Mint some to user1 via minter (aStaking)
        vm.prank(address(aStaking));
        axSumr.mint(user1, 3 ether);

        // Pause by PAUSER_ROLE (aStaking)
        vm.prank(address(aStaking));
        axSumr.pause();

        // Mint should fail while paused
        vm.prank(address(aStaking));
        vm.expectRevert();
        axSumr.mint(user1, 1 ether);

        // BurnFrom should also fail while paused
        vm.prank(address(aStaking));
        vm.expectRevert();
        axSumr.burnFrom(user1, 1 ether);

        // Unpause restores functionality
        vm.prank(address(aStaking));
        axSumr.unpause();

        vm.prank(address(aStaking));
        axSumr.mint(user1, 1 ether);
        assertEq(axSumr.balanceOf(user1), 4 ether);
    }

    function test_AddRemoveStakingModule_GrantsAndRevokesRoles() public {
        bytes32 minterRole = axSumr.MINTER_ROLE();
        bytes32 pauserRole = axSumr.PAUSER_ROLE();
        bytes32 burnerRole = axSumr.BURNER_ROLE();

        // Add module
        vm.prank(address(timelockA));
        axSumr.addStakingModule(minter);
        assertTrue(axSumr.hasRole(minterRole, minter));
        assertTrue(axSumr.hasRole(pauserRole, minter));
        assertTrue(axSumr.hasRole(burnerRole, minter));

        // Remove module
        vm.prank(address(timelockA));
        axSumr.removeStakingModule(minter);
        assertFalse(axSumr.hasRole(minterRole, minter));
        assertFalse(axSumr.hasRole(pauserRole, minter));
        assertFalse(axSumr.hasRole(burnerRole, minter));
    }

    function test_DirectGrantRevoke_Disabled() public {
        // Capture the role constant before setting expectRevert
        bytes32 role = axSumr.MINTER_ROLE();

        // Expect any revert when attempting direct grant/revoke
        vm.expectRevert();
        axSumr.grantRole(role, address(0x1234));

        vm.expectRevert();
        axSumr.revokeRole(role, address(0x1234));
    }
}
