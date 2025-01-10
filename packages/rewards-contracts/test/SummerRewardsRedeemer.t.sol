// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SummerRewardsRedeemer} from "../src/contracts/SummerRewardsRedeemer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {console} from "forge-std/console.sol";
contract RewardsRedeemerTest is Test {
    SummerRewardsRedeemer public redeemer;
    ERC20Mock public rewardsToken;
    ProtocolAccessManager public accessManager;

    address public governor;
    address public alice;
    address public bob;

    // Test data
    bytes32 public constant TEST_ROOT =
        hex"31aad8a5217c14609af1dd5d4b179b22c227e54155b1623c9bccdb97183c8005";
    bytes32 public constant TEST_ROOT_2 =
        hex"cd0de6463cbc6fbfd98fdda50136a3a03264c9b550f075b34164a22cdd1fa34a";
    uint256 public constant TEST_INDEX = 1;
    uint256 public constant TEST_INDEX_2 = 2;
    uint256 public constant TEST_AMOUNT_ALICE = 3 ether;
    uint256 public constant TEST_AMOUNT_ALICE_2 = 1 ether;
    uint256 public constant TEST_AMOUNT_BOB = 2 ether;
    uint256 public constant TEST_AMOUNT_BOB_2 = 2 ether;

    bytes32[] public TEST_PROOF_ALICE;
    bytes32[] public TEST_PROOF_ALICE_2;

    bytes32[] public TEST_PROOF_BOB;
    bytes32[] public TEST_PROOF_BOB_2;

    event Claimed(address indexed user, uint256 indexed index, uint256 amount);
    event RootAdded(uint256 indexed index, bytes32 root);
    event RootRemoved(uint256 indexed index);

    function setUp() public {
        governor = makeAddr("governor");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy mock token and access manager
        rewardsToken = new ERC20Mock();
        accessManager = new ProtocolAccessManager(governor);

        // Deploy redeemer
        redeemer = new SummerRewardsRedeemer(
            address(rewardsToken),
            address(accessManager)
        );

        // Setup test proof for alice
        TEST_PROOF_ALICE = new bytes32[](2);
        TEST_PROOF_ALICE[
            0
        ] = hex"561fb36e5ca9909a808f1e83a1363762ff75b9a121babb0178f6c9fc690a1367";
        TEST_PROOF_ALICE[
            1
        ] = hex"9edac377c4d6abe396e41107eccedbb2741e10f8387a9167c404646631914c4c";

        // Setup test proof for alice - distribution 2
        TEST_PROOF_ALICE_2 = new bytes32[](2);
        TEST_PROOF_ALICE_2[
            0
        ] = hex"561fb36e5ca9909a808f1e83a1363762ff75b9a121babb0178f6c9fc690a1367";
        TEST_PROOF_ALICE_2[
            1
        ] = hex"59bfd8b8aa058effb68dc5d8dadc75a6af9069ec03a5e3e4081284366d553c72";

        // Setup test proof for bob
        TEST_PROOF_BOB = new bytes32[](2);
        TEST_PROOF_BOB[
            0
        ] = hex"4f85b7756d43c5aff03edda5556ddc40391674530def808c54a418a3388845f0";
        TEST_PROOF_BOB[
            1
        ] = hex"9edac377c4d6abe396e41107eccedbb2741e10f8387a9167c404646631914c4c";

        // Setup test proof for bob - distribution 2
        TEST_PROOF_BOB_2 = new bytes32[](2);
        TEST_PROOF_BOB_2[
            0
        ] = hex"42cc8a55e963e0472bfe88474c638d374e1a860c2580fcf2d5ef698fbfd830c3";
        TEST_PROOF_BOB_2[
            1
        ] = hex"59bfd8b8aa058effb68dc5d8dadc75a6af9069ec03a5e3e4081284366d553c72";
    }

    function test_Constructor() public view {
        assertEq(address(redeemer.rewardsToken()), address(rewardsToken));
        assertTrue(redeemer.deployedAt() > 0);
        assertTrue(redeemer.deployedAt() <= block.timestamp);
    }

    function test_Constructor_RevertInvalidToken() public {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidRewardsToken(address)", address(0))
        );
        new SummerRewardsRedeemer(address(0), address(accessManager));
    }

    function test_AddRoot() public {
        vm.startPrank(governor);

        vm.expectEmit(true, false, false, true);
        emit RootAdded(TEST_INDEX, TEST_ROOT);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        assertEq(redeemer.getRoot(TEST_INDEX), TEST_ROOT);
        vm.stopPrank();
    }

    function test_AddRoot_RevertAlreadyAdded() public {
        vm.startPrank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        vm.expectRevert(
            abi.encodeWithSignature(
                "RootAlreadyAdded(uint256,bytes32)",
                TEST_INDEX,
                TEST_ROOT
            )
        );
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);
        vm.stopPrank();
    }

    function test_RemoveRoot() public {
        vm.startPrank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        vm.expectEmit(true, false, false, false);
        emit RootRemoved(TEST_INDEX);
        redeemer.removeRoot(TEST_INDEX);

        assertEq(redeemer.getRoot(TEST_INDEX), bytes32(0));
        vm.stopPrank();
    }

    function test_Claim() public {
        // Mint tokens to redeemer
        rewardsToken.mint(address(redeemer), 1000 ether);

        vm.prank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        vm.startPrank(alice);
        uint256 balanceBefore = rewardsToken.balanceOf(alice);

        vm.expectEmit(true, true, false, true);
        emit Claimed(alice, TEST_INDEX, TEST_AMOUNT_ALICE);
        redeemer.claim(alice, TEST_INDEX, TEST_AMOUNT_ALICE, TEST_PROOF_ALICE);

        assertEq(
            rewardsToken.balanceOf(alice),
            balanceBefore + TEST_AMOUNT_ALICE
        );
        assertTrue(redeemer.hasClaimed(alice, TEST_INDEX));
        vm.stopPrank();

        vm.startPrank(bob);
        balanceBefore = rewardsToken.balanceOf(bob);

        vm.expectEmit(true, true, false, true);
        emit Claimed(bob, TEST_INDEX, TEST_AMOUNT_BOB);
        redeemer.claim(bob, TEST_INDEX, TEST_AMOUNT_BOB, TEST_PROOF_BOB);

        assertEq(rewardsToken.balanceOf(bob), balanceBefore + TEST_AMOUNT_BOB);
        assertTrue(redeemer.hasClaimed(bob, TEST_INDEX));
        vm.stopPrank();
    }

    function test_ClaimMultiple() public {
        // Mint tokens to redeemer
        rewardsToken.mint(address(redeemer), 1000 ether);
        uint256[] memory indices = new uint256[](2);
        indices[0] = TEST_INDEX;
        indices[1] = TEST_INDEX_2;

        uint256[] memory amountsAlice = new uint256[](2);
        amountsAlice[0] = TEST_AMOUNT_ALICE;
        amountsAlice[1] = TEST_AMOUNT_ALICE_2;

        uint256[] memory amountsBob = new uint256[](2);
        amountsBob[0] = TEST_AMOUNT_BOB;
        amountsBob[1] = TEST_AMOUNT_BOB_2;

        bytes32[][] memory proofsAlice = new bytes32[][](2);
        proofsAlice[0] = TEST_PROOF_ALICE;
        proofsAlice[1] = TEST_PROOF_ALICE_2;

        bytes32[][] memory proofsBob = new bytes32[][](2);
        proofsBob[0] = TEST_PROOF_BOB;
        proofsBob[1] = TEST_PROOF_BOB_2;

        vm.startPrank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);
        redeemer.addRoot(TEST_INDEX_2, TEST_ROOT_2);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 balanceBefore = rewardsToken.balanceOf(alice);

        redeemer.claimMultiple(alice, indices, amountsAlice, proofsAlice);

        assertEq(
            rewardsToken.balanceOf(alice),
            balanceBefore + TEST_AMOUNT_ALICE + TEST_AMOUNT_ALICE_2
        );
        assertTrue(redeemer.hasClaimed(alice, TEST_INDEX));
        assertTrue(redeemer.hasClaimed(alice, TEST_INDEX_2));
        vm.stopPrank();

        vm.startPrank(bob);
        balanceBefore = rewardsToken.balanceOf(bob);

        redeemer.claimMultiple(bob, indices, amountsBob, proofsBob);

        assertEq(
            rewardsToken.balanceOf(bob),
            balanceBefore + TEST_AMOUNT_BOB + TEST_AMOUNT_BOB_2
        );
        assertTrue(redeemer.hasClaimed(bob, TEST_INDEX));
        assertTrue(redeemer.hasClaimed(bob, TEST_INDEX_2));
        vm.stopPrank();
    }

    function test_ClaimMultiple_RevertEmptyArrays() public {
        uint256[] memory emptyIndices = new uint256[](0);
        uint256[] memory emptyAmounts = new uint256[](0);
        bytes32[][] memory emptyProofs = new bytes32[][](0);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ClaimMultipleEmpty(uint256[],uint256[],bytes32[][])",
                emptyIndices,
                emptyAmounts,
                emptyProofs
            )
        );
        redeemer.claimMultiple(alice, emptyIndices, emptyAmounts, emptyProofs);
    }

    function test_EmergencyWithdraw() public {
        // Mint tokens to redeemer
        rewardsToken.mint(address(redeemer), 1000 ether);

        uint256 amount = 50 ether;
        address recipient = makeAddr("recipient");

        vm.prank(governor);
        redeemer.emergencyWithdraw(address(rewardsToken), recipient, amount);

        assertEq(rewardsToken.balanceOf(recipient), amount);
    }

    function test_EmergencyWithdraw_RevertNotGovernor() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotGovernor(address)",
                address(this)
            )
        );
        redeemer.emergencyWithdraw(address(rewardsToken), alice, 1 ether);
    }

    function test_DeployTime() public view {
        assertTrue(redeemer.deployedAt() > 0);
        assertTrue(redeemer.deployedAt() <= block.timestamp);
    }

    function test_RootManagement() public {
        vm.startPrank(governor);

        // Add roots
        redeemer.addRoot(0, TEST_ROOT);
        assertEq(redeemer.roots(0), TEST_ROOT);

        redeemer.addRoot(1, TEST_ROOT);
        assertEq(redeemer.roots(1), TEST_ROOT);

        // Remove root
        redeemer.removeRoot(0);
        assertEq(redeemer.roots(0), bytes32(0));

        vm.stopPrank();
    }

    function test_RootManagement_RevertNotGovernor() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotGovernor(address)",
                address(this)
            )
        );
        redeemer.addRoot(0, TEST_ROOT);

        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotGovernor(address)",
                address(this)
            )
        );
        redeemer.removeRoot(0);
    }

    function test_RootManagement_RevertDuplicateRoot() public {
        vm.startPrank(governor);
        redeemer.addRoot(0, TEST_ROOT);

        vm.expectRevert(
            abi.encodeWithSignature(
                "RootAlreadyAdded(uint256,bytes32)",
                0,
                TEST_ROOT
            )
        );
        redeemer.addRoot(0, TEST_ROOT);

        vm.stopPrank();
    }

    function test_CanClaim_ValidClaim() public {
        vm.prank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        vm.prank(alice);
        assertTrue(
            redeemer.canClaim(
                alice,
                TEST_INDEX,
                TEST_AMOUNT_ALICE,
                TEST_PROOF_ALICE
            )
        );
    }

    function test_CanClaim_InvalidIndex() public {
        vm.prank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        vm.prank(alice);
        assertFalse(
            redeemer.canClaim(
                alice,
                TEST_INDEX + 1,
                TEST_AMOUNT_ALICE,
                TEST_PROOF_ALICE
            )
        );
    }

    function test_CanClaim_InvalidAmount() public {
        vm.prank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        assertFalse(
            redeemer.canClaim(
                alice,
                TEST_INDEX,
                TEST_AMOUNT_ALICE + 1,
                TEST_PROOF_ALICE
            )
        );
    }

    function test_CanClaim_InvalidProof() public {
        vm.prank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        assertFalse(
            redeemer.canClaim(
                alice,
                TEST_INDEX,
                TEST_AMOUNT_ALICE,
                TEST_PROOF_BOB
            )
        );
    }

    function test_ClaimMultiple_DifferentLengths() public {
        uint256[] memory indices = new uint256[](2);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](2);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ClaimMultipleLengthMismatch(uint256[],uint256[],bytes32[][])",
                indices,
                amounts,
                proofs
            )
        );
        redeemer.claimMultiple(alice, indices, amounts, proofs);
    }

    function test_ClaimMultiple_DuplicateIndex() public {
        uint256[] memory indices = new uint256[](2);
        indices[0] = TEST_INDEX;
        indices[1] = TEST_INDEX;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = TEST_AMOUNT_ALICE;
        amounts[1] = TEST_AMOUNT_ALICE;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = TEST_PROOF_ALICE;
        proofs[1] = TEST_PROOF_ALICE;

        vm.prank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "UserAlreadyClaimed(address,uint256,uint256,bytes32[])",
                alice,
                TEST_INDEX,
                TEST_AMOUNT_ALICE,
                TEST_PROOF_ALICE
            )
        );
        redeemer.claimMultiple(alice, indices, amounts, proofs);
        vm.stopPrank();
    }

    function test_ClaimMultiple_InsufficientBalance() public {
        uint256[] memory indices = new uint256[](2);
        indices[0] = TEST_INDEX;
        indices[1] = TEST_INDEX_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = TEST_AMOUNT_ALICE;
        amounts[1] = TEST_AMOUNT_ALICE_2;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = TEST_PROOF_ALICE;
        proofs[1] = TEST_PROOF_ALICE_2;

        vm.startPrank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);
        redeemer.addRoot(TEST_INDEX_2, TEST_ROOT_2);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                address(redeemer),
                0,
                4 ether
            )
        );
        redeemer.claimMultiple(alice, indices, amounts, proofs);
    }

    function test_ClaimMultiple_MsgSender() public {
        // Mint tokens to redeemer
        rewardsToken.mint(address(redeemer), 1000 ether);

        uint256[] memory indices = new uint256[](2);
        indices[0] = TEST_INDEX;
        indices[1] = TEST_INDEX_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = TEST_AMOUNT_ALICE;
        amounts[1] = TEST_AMOUNT_ALICE_2;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = TEST_PROOF_ALICE;
        proofs[1] = TEST_PROOF_ALICE_2;

        vm.startPrank(governor);
        redeemer.addRoot(TEST_INDEX, TEST_ROOT);
        redeemer.addRoot(TEST_INDEX_2, TEST_ROOT_2);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 balanceBefore = rewardsToken.balanceOf(alice);

        // Call the overloaded version without user parameter
        redeemer.claimMultiple(indices, amounts, proofs);

        assertEq(
            rewardsToken.balanceOf(alice),
            balanceBefore + TEST_AMOUNT_ALICE + TEST_AMOUNT_ALICE_2
        );
        assertTrue(redeemer.hasClaimed(alice, TEST_INDEX));
        assertTrue(redeemer.hasClaimed(alice, TEST_INDEX_2));
        vm.stopPrank();
    }
}
