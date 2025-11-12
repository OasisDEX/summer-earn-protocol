// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StakedSummerToken} from "../../src/contracts/StakedSummerToken.sol";
import {SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {IStakedSummerToken} from "../../src/interfaces/IStakedSummerToken.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
/*
 * @title StakedSummerToken Basic Tests
 * @notice Covers pausing/unpausing, mint permissions, transfers while paused,
 *         staking module role management, and burn behaviors.
 */
contract StakedSummerTokenBasicTest is SummerGovernorV2TestBase {
    uint256 internal constant MINT_AMOUNT = 1_000 ether;

    function test_PauseBlocksMinting() public {
        vm.startPrank(address(timelockA));
        axSumr.mint(alice, MINT_AMOUNT);
        axSumr.pause();
        vm.stopPrank();
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        axSumr.mint(alice, 1 ether);
        vm.stopPrank();
    }
    function test_PauseBlocksBurnsAndUnpauseRestores() public {
        // Mint tokens to Alice via governor (timelockA has governor privileges)
        vm.startPrank(address(timelockA));
        axSumr.mint(alice, MINT_AMOUNT);
        axSumr.pause();
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        axSumr.burn(1 ether);

        vm.prank(address(timelockA));
        axSumr.unpause();

        uint256 aliceBefore = axSumr.balanceOf(alice);

        vm.prank(alice);
        axSumr.burn(1 ether);

        assertEq(
            axSumr.balanceOf(alice),
            aliceBefore - 1 ether,
            "alice should have 1 staked token less"
        );
    }

    function test_Revert_PauseByNonPrivileged() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotGuardianOrGovernor(address)",
                alice
            )
        );
        vm.prank(alice);
        axSumr.pause();
    }

    function test_MintingRequiresMinterRole_GrantAndRevoke() public {
        // Non-minter cannot mint
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                alice,
                axSumr.MINTER_ROLE()
            )
        );
        axSumr.mint(bob, 1 ether);
        vm.stopPrank();

        // Governor grants MINTER role to Alice
        vm.prank(address(timelockA));
        axSumr.grantMinterRole(alice);
        assertTrue(axSumr.hasRole(axSumr.MINTER_ROLE(), alice));

        // Alice can mint now
        uint256 bobBefore = axSumr.balanceOf(bob);
        vm.prank(alice);
        axSumr.mint(bob, 2 ether);
        assertEq(axSumr.balanceOf(bob), bobBefore + 2 ether);

        // Governor revokes MINTER role from Alice
        vm.prank(address(timelockA));
        axSumr.revokeMinterRole(alice);
        assertFalse(axSumr.hasRole(axSumr.MINTER_ROLE(), alice));

        // Alice can no longer mint
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                alice,
                axSumr.MINTER_ROLE()
            )
        );
        axSumr.mint(bob, 1 ether);
        vm.stopPrank();
    }

    function test_AddRemoveStakingModule_OnlyGovernor_EffectsMinterRole()
        public
    {
        // Only governor can add staking module, which grants MINTER_ROLE
        vm.prank(address(timelockA));
        axSumr.addStakingModule(alice);
        assertTrue(axSumr.hasRole(axSumr.MINTER_ROLE(), alice));

        // Alice can mint while having the role
        uint256 bobBefore = axSumr.balanceOf(bob);
        vm.prank(alice);
        axSumr.mint(bob, 3 ether);
        assertEq(axSumr.balanceOf(bob), bobBefore + 3 ether);

        // Only governor can remove staking module (revoke MINTER_ROLE)
        vm.prank(address(timelockA));
        axSumr.removeStakingModule(alice);
        assertFalse(axSumr.hasRole(axSumr.MINTER_ROLE(), alice));

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                alice,
                axSumr.MINTER_ROLE()
            )
        );
        axSumr.mint(bob, 1 ether);
        vm.stopPrank();
    }

    function test_Revert_AddStakingModule_ZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStakedSummerToken.xSumr_InvalidStakingModule.selector,
                "Staking module address cannot be zero"
            )
        );
        vm.prank(address(timelockA));
        axSumr.addStakingModule(address(0));
    }

    function test_DirectGrantRoleAndRevokeRole_Disabled() public {
        bytes32 minterRole = axSumr.MINTER_ROLE();

        vm.startPrank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature(
                "DirectGrantIsDisabled(address)",
                address(timelockA)
            )
        );
        axSumr.grantRole(minterRole, alice);

        vm.expectRevert(
            abi.encodeWithSignature(
                "DirectRevokeIsDisabled(address)",
                address(timelockA)
            )
        );
        axSumr.revokeRole(minterRole, alice);
        vm.stopPrank();
    }

    function test_BurnReducesBalanceAndSupply() public {
        // Mint to Alice and then burn
        vm.prank(address(timelockA));
        axSumr.mint(alice, MINT_AMOUNT);

        uint256 totalBefore = axSumr.totalSupply();
        uint256 aliceBefore = axSumr.balanceOf(alice);

        vm.startPrank(alice);
        axSumr.burn(400 ether);

        assertEq(axSumr.totalSupply(), totalBefore - 400 ether);
        assertEq(axSumr.balanceOf(alice), aliceBefore - 400 ether);
        vm.stopPrank();
    }

    // ============ burnFrom() TESTS ============

    function test_BurnFrom_ByOwnerWithoutAllowance_Reverts() public {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 5 ether);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                alice,
                0,
                1 ether
            )
        );
        axSumr.burnFrom(alice, 1 ether);
    }

    function test_BurnFrom_ByOwnerWithAllowance_Succeeds_AndDecreasesAllowance()
        public
    {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 10 ether);

        // Owner approves self to spend and then burns via burnFrom
        vm.startPrank(alice);
        axSumr.approve(alice, 6 ether);
        uint256 supplyBefore = axSumr.totalSupply();
        uint256 balanceBefore = axSumr.balanceOf(alice);
        axSumr.burnFrom(alice, 2 ether);
        vm.stopPrank();

        assertEq(axSumr.totalSupply(), supplyBefore - 2 ether);
        assertEq(axSumr.balanceOf(alice), balanceBefore - 2 ether);
        assertEq(axSumr.allowance(alice, alice), 4 ether);
    }

    function test_BurnFrom_ByNonOwner_NoBurnerRole_Reverts_NotAuthorized()
        public
    {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 5 ether);

        vm.prank(bob);
        vm.expectRevert(IStakedSummerToken.xSumr__NotAuthorized.selector);
        axSumr.burnFrom(alice, 1 ether);
    }

    function test_BurnFrom_ByNonOwner_WithAllowance_NoBurnerRole_Reverts_NotAuthorized()
        public
    {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 5 ether);

        vm.prank(alice);
        axSumr.approve(bob, 2 ether);

        vm.prank(bob);
        vm.expectRevert(IStakedSummerToken.xSumr__NotAuthorized.selector);
        axSumr.burnFrom(alice, 1 ether);
    }

    function test_BurnFrom_ByBurnerRoleWithoutAllowance_RevertsAllowance()
        public
    {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 5 ether);

        // Grant BURNER_ROLE via staking module
        vm.prank(address(timelockA));
        axSumr.addStakingModule(bob);
        assertTrue(axSumr.hasRole(axSumr.BURNER_ROLE(), bob));

        // No allowance set, so allowance check should revert in super.burnFrom
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                bob,
                0,
                1 ether
            )
        );
        axSumr.burnFrom(alice, 1 ether);
    }

    function test_BurnFrom_ByBurnerRoleWithAllowance_Succeeds() public {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 10 ether);

        vm.prank(address(timelockA));
        axSumr.addStakingModule(bob);
        assertTrue(axSumr.hasRole(axSumr.BURNER_ROLE(), bob));

        vm.prank(alice);
        axSumr.approve(bob, 7 ether);

        uint256 supplyBefore = axSumr.totalSupply();
        uint256 balanceBefore = axSumr.balanceOf(alice);

        vm.prank(bob);
        axSumr.burnFrom(alice, 5 ether);

        assertEq(axSumr.totalSupply(), supplyBefore - 5 ether);
        assertEq(axSumr.balanceOf(alice), balanceBefore - 5 ether);
        assertEq(axSumr.allowance(alice, bob), 2 ether);
    }

    function test_BurnFrom_ByBurnerRoleWithMaxAllowance_DoesNotDecreaseAllowance()
        public
    {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 10 ether);

        vm.prank(address(timelockA));
        axSumr.addStakingModule(bob);

        vm.prank(alice);
        axSumr.approve(bob, type(uint256).max);

        vm.prank(bob);
        axSumr.burnFrom(alice, 1 ether);

        assertEq(axSumr.allowance(alice, bob), type(uint256).max);
    }

    function test_BurnFrom_Paused_Reverts() public {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 10 ether);

        // Grant burner to bob and pause token
        vm.startPrank(address(timelockA));
        axSumr.addStakingModule(bob);
        axSumr.pause();
        vm.stopPrank();

        vm.prank(alice);
        axSumr.approve(bob, 3 ether);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        axSumr.burnFrom(alice, 1 ether);
    }

    function test_BurnFrom_ByOwner_Paused_Reverts() public {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 10 ether);

        vm.prank(address(timelockA));
        axSumr.pause();

        vm.startPrank(alice);
        axSumr.approve(alice, 2 ether);
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        axSumr.burnFrom(alice, 1 ether);
        vm.stopPrank();
    }

    function test_TransferNotAllowed() public {
        vm.prank(address(timelockA));
        axSumr.mint(alice, 10 ether);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStakedSummerToken.xSumr_TransferNotAllowed.selector
            )
        );
        axSumr.transfer(bob, 1 ether);

        vm.prank(alice);
        axSumr.approve(bob, 1 ether);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStakedSummerToken.xSumr_TransferNotAllowed.selector
            )
        );
        axSumr.transferFrom(alice, bob, 1 ether);
    }
}
