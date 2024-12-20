// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SummerGovernorEIP712Test is SummerGovernorTestBase {
    using MessageHashUtils for bytes32;

    // Private keys for testing
    uint256 private constant ALICE_PRIVATE_KEY = 0xa11ce;
    uint256 private constant BOB_PRIVATE_KEY = 0xb0b;

    bytes32 public constant BALLOT_TYPEHASH =
        keccak256(
            "Ballot(uint256 proposalId,uint8 support,address voter,uint256 nonce)"
        );

    bytes32 public constant EXTENDED_BALLOT_TYPEHASH =
        keccak256(
            "ExtendedBallot(uint256 proposalId,uint8 support,address voter,uint256 nonce,string reason,bytes params)"
        );

    function setUp() public override {
        // Override alice and bob addresses with ones derived from private keys
        alice = vm.addr(ALICE_PRIVATE_KEY);
        bob = vm.addr(BOB_PRIVATE_KEY);

        // Now call parent setUp with our new addresses
        super.setUp();
    }

    function test_BallotTypeHash() public view {
        assertEq(governorA.BALLOT_TYPEHASH(), BALLOT_TYPEHASH);
    }

    function test_ExtendedBallotTypeHash() public view {
        assertEq(
            governorA.EXTENDED_BALLOT_TYPEHASH(),
            EXTENDED_BALLOT_TYPEHASH
        );
    }

    function test_EIP712Domain() public view {
        (
            ,
            // bytes1 fields (unused)
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = governorA.eip712Domain();

        // Verify domain fields
        assertEq(name, "SummerGovernor");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(governorA));
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }

    function test_CastVoteBySig() public {
        // Setup proposal and voter
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Get current nonce for the voter
        uint256 nonce = governorA.nonces(alice);

        // Create vote signature
        uint8 support = 1;
        bytes32 structHash = keccak256(
            abi.encode(
                BALLOT_TYPEHASH,
                proposalId,
                support,
                alice, // voter
                nonce // nonce
            )
        );

        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Cast vote using signature
        governorA.castVoteBySig(proposalId, support, alice, signature);

        // Verify vote was counted
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);
        assertEq(forVotes, governorA.proposalThreshold());
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function test_CastVoteWithReasonAndParamsBySig() public {
        // Setup proposal and voter
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Get current nonce for the voter
        uint256 nonce = governorA.nonces(alice);

        // Create vote signature with reason and params
        uint8 support = 1;
        string memory reason = "I support this proposal";
        bytes memory params = "";

        // Calculate domain separator
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("SummerGovernor")),
                keccak256(bytes("1")),
                block.chainid,
                address(governorA)
            )
        );

        // Calculate struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                EXTENDED_BALLOT_TYPEHASH,
                proposalId,
                support,
                alice,
                nonce,
                keccak256(bytes(reason)),
                keccak256(params)
            )
        );

        // Calculate final digest
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Cast vote with reason and params using signature
        governorA.castVoteWithReasonAndParamsBySig(
            proposalId,
            support,
            alice,
            reason,
            params,
            signature
        );

        // Verify vote was counted
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);
        assertEq(forVotes, governorA.proposalThreshold());
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }

    function testRevert_InvalidSignature() public {
        // Setup proposal and voter
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Create invalid signature (wrong private key)
        uint8 support = 1;
        bytes32 structHash = keccak256(
            abi.encode(BALLOT_TYPEHASH, proposalId, support)
        );

        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(BOB_PRIVATE_KEY, digest); // Using Bob's key instead of Alice's
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempt to cast vote with invalid signature
        vm.expectRevert(
            abi.encodeWithSignature("GovernorInvalidSignature(address)", alice)
        );
        governorA.castVoteBySig(proposalId, support, alice, signature);
    }

    function test_Nonces() public {
        // Initial nonce should be 0
        assertEq(governorA.nonces(alice), 0);

        // Setup proposal and voter
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.proposalThreshold());
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Get current nonce
        uint256 nonce = governorA.nonces(alice);

        // Create vote signature
        uint8 support = 1;
        bytes32 structHash = keccak256(
            abi.encode(
                BALLOT_TYPEHASH,
                proposalId,
                support,
                alice, // voter
                nonce // nonce
            )
        );

        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Cast vote using signature
        governorA.castVoteBySig(proposalId, support, alice, signature);

        // Nonce should be incremented after vote
        assertEq(governorA.nonces(alice), 1);
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("SummerGovernor")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(governorA)
                )
            );
    }
}
