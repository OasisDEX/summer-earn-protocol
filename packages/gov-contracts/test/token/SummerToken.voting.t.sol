// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {console} from "forge-std/console.sol";
import {Votes} from "@openzeppelin/contracts/governance/utils/Votes.sol";

contract SummerTokenVotingTest is SummerTokenTestBase {
    address public alice;
    address public bob;
    address public charlie;

    function setUp() public virtual override {
        super.setUp();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        enableTransfers(); // Enable transfers for testing
    }

    function test_InitialDelegation() public {
        assertEq(aSummerToken.getVotes(alice), 0);

        aSummerToken.transfer(alice, 100 ether);
        assertEq(aSummerToken.getVotes(alice), 0);

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Transfer half balance
        vm.prank(alice);
        aSummerToken.transfer(bob, 50 ether);

        // Check historical votes
        assertEq(
            aSummerToken.getPastVotes(alice, block.timestamp - 1),
            100 ether
        );
        assertEq(aSummerToken.getVotes(alice), 50 ether);

        // Bob delegates to self
        vm.prank(bob);
        aSummerToken.delegate(bob);
        assertEq(aSummerToken.getVotes(bob), 50 ether);
    }

    function test_Delegation() public {
        aSummerToken.transfer(alice, 100 ether);
        aSummerToken.transfer(bob, 50 ether);

        vm.prank(alice);
        aSummerToken.delegate(alice);
        assertEq(aSummerToken.getVotes(alice), 100 ether);

        vm.prank(alice);
        aSummerToken.delegate(bob);
        assertEq(aSummerToken.getVotes(alice), 0);
        assertEq(aSummerToken.getVotes(bob), 100 ether);

        vm.prank(bob);
        aSummerToken.delegate(bob);
        assertEq(aSummerToken.getVotes(bob), 150 ether);
    }

    function test_DelegationChain() public {
        aSummerToken.transfer(alice, 100 ether);
        aSummerToken.transfer(bob, 50 ether);
        aSummerToken.transfer(charlie, 25 ether);

        vm.prank(charlie);
        aSummerToken.delegate(bob);

        vm.prank(bob);
        aSummerToken.delegate(alice);

        vm.prank(alice);
        aSummerToken.delegate(alice);

        assertEq(aSummerToken.getVotes(alice), 150 ether);
        assertEq(aSummerToken.getVotes(bob), 25 ether);
        assertEq(aSummerToken.getVotes(charlie), 0);
    }

    function test_HistoricalVotes() public {
        // Initial setup at block N
        aSummerToken.transfer(alice, 100e18);

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        aSummerToken.transfer(alice, 50e18);

        // Check historical votes at block N+1
        assertEq(aSummerToken.getPastVotes(alice, block.timestamp - 1), 100e18);
    }

    function test_CheckpointsAccess() public {
        aSummerToken.transfer(alice, 100 ether);

        vm.prank(alice);
        aSummerToken.delegate(alice);

        Checkpoints.Checkpoint208 memory checkpoint = aSummerToken.checkpoints(
            alice,
            0
        );
        assertEq(checkpoint._value, 100 ether);
        assertTrue(checkpoint._key > 0);
    }

    function test_NumCheckpoints() public {
        aSummerToken.transfer(alice, 100 ether);

        vm.prank(alice);
        aSummerToken.delegate(alice);
        assertEq(aSummerToken.numCheckpoints(alice), 1);

        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        aSummerToken.transfer(bob, 50 ether);

        assertEq(aSummerToken.numCheckpoints(alice), 2);
    }

    function test_DelegateToZeroAddress() public {
        aSummerToken.transfer(alice, 100 ether);

        vm.prank(alice);
        aSummerToken.delegate(address(0));

        assertEq(aSummerToken.delegates(alice), address(0));
        assertEq(aSummerToken.getVotes(address(0)), 0);
        assertEq(aSummerToken.getVotes(alice), 0);
    }

    function test_TransferAfterDelegation() public {
        aSummerToken.transfer(alice, 100 ether);

        vm.prank(alice);
        aSummerToken.delegate(bob);

        vm.prank(alice);
        aSummerToken.transfer(charlie, 50 ether);

        assertEq(aSummerToken.getVotes(bob), 50 ether);
        assertEq(aSummerToken.getVotes(charlie), 0);
    }

    function test_DelegateBySig() public {
        aSummerToken.transfer(alice, 100 ether);

        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);
        aSummerToken.transfer(signer, 100 ether);

        // Prepare signature data
        uint256 nonce = aSummerToken.nonces(signer);
        uint256 expiry = block.timestamp + 1 hours;

        // Construct the digest according to EIP-712
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Delegation(address delegatee,uint256 nonce,uint256 expiry)"
                ),
                bob,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                aSummerToken.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        aSummerToken.delegateBySig(bob, nonce, expiry, v, r, s);

        assertEq(aSummerToken.delegates(signer), bob);
        assertEq(aSummerToken.getVotes(bob), 100 ether);
    }

    function test_DelegateBySig_ExpiredSignature() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);
        aSummerToken.transfer(signer, 100 ether);

        uint256 nonce = aSummerToken.nonces(signer);
        uint256 expiry = block.timestamp - 1; // Expired timestamp

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Delegation(address delegatee,uint256 nonce,uint256 expiry)"
                ),
                bob,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                aSummerToken.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(
            abi.encodeWithSignature("VotesExpiredSignature(uint256)", expiry)
        );
        aSummerToken.delegateBySig(bob, nonce, expiry, v, r, s);
    }

    function test_GetPastTotalSupply() public {
        // Move time forward
        vm.warp(87402);

        // Query a timestamp in the past (less than current time)
        uint256 result = aSummerToken.getPastTotalSupply(87401);
        assertEq(result, INITIAL_SUPPLY * 1e18);
    }

    function test_GetPastTotalSupply_FutureLookup() public {
        vm.warp(86402);

        vm.expectRevert(
            abi.encodeWithSelector(
                Votes.ERC5805FutureLookup.selector,
                86403, // timepoint
                86402 // current clock value
            )
        );
        aSummerToken.getPastTotalSupply(86403);
    }

    function test_ClockMode() public view {
        string memory clockMode = aSummerToken.CLOCK_MODE();
        assertEq(clockMode, "mode=timestamp");
    }

    function test_Clock() public view {
        assertEq(aSummerToken.clock(), 86402);
    }

    function test_ComplexDelegationScenario() public {
        // Do transfers and delegations
        aSummerToken.transfer(alice, 100e18);
        aSummerToken.transfer(bob, 50e18);
        aSummerToken.transfer(charlie, 25e18);

        vm.prank(alice);
        aSummerToken.delegate(bob);
        vm.prank(bob);
        aSummerToken.delegate(charlie);
        vm.prank(charlie);
        aSummerToken.delegate(charlie);

        // Move time forward
        vm.warp(block.timestamp + 1);

        // Now query the past timestamp
        assertEq(
            aSummerToken.getPastVotes(charlie, block.timestamp - 1),
            75e18
        );
    }

    function test_DelegationWithTransfers() public {
        aSummerToken.transfer(alice, 100 ether);

        vm.prank(alice);
        aSummerToken.delegate(alice);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        // Transfer half balance
        vm.prank(alice);
        aSummerToken.transfer(bob, 50 ether);

        // Check historical votes
        assertEq(
            aSummerToken.getPastVotes(alice, block.timestamp - 1),
            100 ether
        );
        assertEq(aSummerToken.getVotes(alice), 50 ether);

        // Bob delegates to self
        vm.prank(bob);
        aSummerToken.delegate(bob);
        assertEq(aSummerToken.getVotes(bob), 50 ether);
    }
}
