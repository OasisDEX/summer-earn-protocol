// SPDX-License-Identifier: BUSL-1.1
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

        // Create the digest that needs to be signed
        bytes32 structHash = keccak256(
            abi.encode(BALLOT_TYPEHASH, proposalId, support, alice, nonce)
        );

        // Use _calculateDomainSeparator() helper function
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

        bytes32 structHash = keccak256(
            abi.encode(
                EXTENDED_BALLOT_TYPEHASH,
                proposalId,
                support,
                alice, // voter
                nonce,
                keccak256(bytes(reason)),
                keccak256(params)
            )
        );

        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Cast vote with reason and params using signature
        uint256 weight = governorA.castVoteWithReasonAndParamsBySig(
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

        assertEq(forVotes, weight);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
        assertTrue(governorA.hasVoted(proposalId, alice));
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

    function test_CastVoteWithReasonBySig() public {
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

        // Create vote signature with reason
        uint8 support = 1;
        string memory reason = "I support this proposal";
        bytes memory params = "";

        bytes32 structHash = keccak256(
            abi.encode(
                EXTENDED_BALLOT_TYPEHASH,
                proposalId,
                support,
                alice, // voter
                nonce,
                keccak256(bytes(reason)),
                keccak256(params)
            )
        );

        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Cast vote with reason using signature
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

        // Verify vote was recorded
        assertTrue(governorA.hasVoted(proposalId, alice));
    }

    function test_CastVoteWithReason() public {
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

        // Cast vote with reason
        string memory reason = "I support this proposal";
        vm.prank(alice);
        governorA.castVoteWithReason(proposalId, 1, reason);

        // Verify vote was counted
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);
        assertEq(forVotes, governorA.proposalThreshold());
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);

        // Verify vote was recorded
        assertTrue(governorA.hasVoted(proposalId, alice));
    }

    function test_CastVoteWithReasonAndParams() public {
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

        // Cast vote with reason and params
        string memory reason = "I support this proposal";
        bytes memory params = abi.encode(uint256(123)); // Example params
        vm.prank(alice);
        governorA.castVoteWithReasonAndParams(proposalId, 1, reason, params);

        // Verify vote was counted
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);
        assertEq(forVotes, governorA.proposalThreshold());
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);

        // Verify vote was recorded
        assertTrue(governorA.hasVoted(proposalId, alice));
    }

    function test_GetVotes() public {
        // Setup voter with tokens
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, 100e18);
        vm.stopPrank();

        // Self-delegate to activate voting power
        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Advance block to ensure delegation is active
        advanceTimeAndBlock();
        // Check votes
        uint256 votes = governorA.getVotes(alice, block.timestamp - 1);
        assertEq(votes, 100e18);
    }

    function test_GetVotesWithParams() public {
        // Setup voter with tokens
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, 100e18);
        vm.stopPrank();

        // Self-delegate to activate voting power
        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Advance block to ensure delegation is active
        advanceTimeAndBlock();

        // Check votes with params (empty params in this case)
        uint256 votes = governorA.getVotesWithParams(
            alice,
            block.timestamp - 1,
            ""
        );
        assertEq(votes, 100e18);
    }

    function test_HasVoted() public {
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

        // Verify hasn't voted
        assertFalse(governorA.hasVoted(proposalId, alice));

        // Cast vote
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Verify has voted
        assertTrue(governorA.hasVoted(proposalId, alice));
    }

    function test_Version() public view {
        assertEq(governorA.version(), "1");
    }

    function test_Name() public view {
        assertEq(governorA.name(), "SummerGovernor");
    }

    function testRevert_InvalidSignatureLength() public {
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

        // Try to cast vote with invalid signature length
        bytes memory invalidSignature = new bytes(63); // Valid signature is 65 bytes

        // Update the expected revert message to match the actual error
        vm.expectRevert(
            abi.encodeWithSignature("GovernorInvalidSignature(address)", alice)
        );
        governorA.castVoteBySig(proposalId, 1, alice, invalidSignature);
    }

    function test_PreventSignatureReplay() public {
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

        // Create vote signature
        uint8 support = 1;
        uint256 nonce = governorA.nonces(alice);
        bytes32 structHash = keccak256(
            abi.encode(BALLOT_TYPEHASH, proposalId, support, alice, nonce)
        );
        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First vote should succeed
        governorA.castVoteBySig(proposalId, support, alice, signature);

        // Second attempt with same signature should fail with GovernorInvalidSignature
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorInvalidSignature.selector,
                alice
            )
        );
        governorA.castVoteBySig(proposalId, support, alice, signature);
    }

    function test_NonceIncrement() public {
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

        // Get initial nonce
        uint256 initialNonce = governorA.nonces(alice);

        // Create and submit first vote
        uint8 support = 1;
        bytes32 structHash = keccak256(
            abi.encode(
                BALLOT_TYPEHASH,
                proposalId,
                support,
                alice,
                initialNonce
            )
        );
        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        governorA.castVoteBySig(proposalId, support, alice, signature);

        // Verify nonce was incremented
        assertEq(
            governorA.nonces(alice),
            initialNonce + 1,
            "Nonce should increment after vote"
        );
    }

    function test_VotingPowerIntegration() public {
        // Setup proposal and voter with specific voting power
        uint256 votingPower = governorA.proposalThreshold(); // Use the actual required threshold
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, votingPower);
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        // Create proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();
        advanceTimeForVotingDelay();

        // Create vote signature
        uint8 support = 1;
        uint256 nonce = governorA.nonces(alice);
        bytes32 structHash = keccak256(
            abi.encode(BALLOT_TYPEHASH, proposalId, support, alice, nonce)
        );
        bytes32 domainSeparator = _calculateDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Cast vote
        governorA.castVoteBySig(proposalId, support, alice, signature);

        // Verify votes were counted according to voting power
        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governorA.proposalVotes(proposalId);
        assertEq(forVotes, votingPower, "Votes should match voting power");
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);
    }
}
