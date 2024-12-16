// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {console} from "forge-std/console.sol";
contract SummerTokenDecayTest is SummerTokenTestBase {
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    uint256 constant TRANSFER_AMOUNT = 1000 ether;
    uint256 internal constant DECAY_RATE = 3.1709792e9; // ~10% per year
    uint40 constant DECAY_FREE_WINDOW = 7 days;

    event DecayUpdated(address account, uint256 newDecayFactor);
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    function setUp() public virtual override {
        super.setUp();
        enableTransfers();

        // Initial token distribution
        aSummerToken.transfer(user1, TRANSFER_AMOUNT);
        aSummerToken.transfer(user2, TRANSFER_AMOUNT);
        aSummerToken.transfer(user3, TRANSFER_AMOUNT);
    }

    // ======== Delegation tests ========

    function test_InitialDelegation() public {
        vm.prank(user1);
        aSummerToken.delegate(user2);

        assertEq(aSummerToken.delegates(user1), user2);
        assertEq(aSummerToken.getVotes(user2), TRANSFER_AMOUNT);
        assertEq(aSummerToken.getVotes(user1), 0);
    }

    function test_DelegationChain() public {
        // Create delegation chain: user1 -> user2 -> user3
        vm.prank(user1);
        aSummerToken.delegate(user2);

        vm.prank(user2);
        aSummerToken.delegate(user3);

        // Check delegation chain length
        assertEq(aSummerToken.getDelegationChainLength(user1), 2);

        // Verify voting power
        assertEq(aSummerToken.getVotes(user3), TRANSFER_AMOUNT);
        assertEq(aSummerToken.getVotes(user2), TRANSFER_AMOUNT);
        assertEq(aSummerToken.getVotes(user1), 0);
    }

    function test_DelegationChainMaxDepth() public {
        address user4 = address(0x4);
        address userEnd = address(0x5);

        // Create max depth delegation chain: user1 -> user2 -> user3 -> user4 -> userEnd
        vm.prank(user1);
        aSummerToken.delegate(user2);

        vm.prank(user2);
        aSummerToken.delegate(user3);

        vm.prank(user3);
        aSummerToken.delegate(user4);

        vm.prank(user4);
        aSummerToken.delegate(userEnd);

        // Check that voting power decays to 0 due to exceeding max depth
        assertEq(aSummerToken.getVotes(userEnd), 0);
        assertEq(aSummerToken.getDelegationChainLength(user1), 4);
    }

    // ======== Decay tests ========

    function test_DecayAfterWindow() public {
        vm.prank(user1);
        aSummerToken.delegate(user2);

        // Move past decay free window
        vm.warp(block.timestamp + DECAY_FREE_WINDOW + 1 days);

        // Force decay update
        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user1);

        // Calculate expected decay
        uint256 expectedVotes = (TRANSFER_AMOUNT *
            (Constants.WAD - (DECAY_RATE * 1 days) / Constants.WAD)) /
            Constants.WAD;
        assertApproxEqRel(aSummerToken.getVotes(user2), expectedVotes, 1e16); // 1% tolerance
    }

    function test_HistoricalVotingPower() public {
        vm.prank(user1);
        aSummerToken.delegate(user2);

        // Store current timestamp
        uint256 checkpoint1 = block.timestamp;

        // Move time forward
        uint256 newTimestamp = block.timestamp + DECAY_FREE_WINDOW + 1 days;
        vm.warp(newTimestamp);

        // Create a checkpoint by doing a delegation
        vm.prank(user1);
        aSummerToken.delegate(user2); // Re-delegate to create checkpoint

        // Move to next block before updating decay
        vm.warp(block.timestamp + 1);

        // Now update decay factor
        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user1);

        // Check historical voting power
        assertEq(
            aSummerToken.getPastVotes(user2, block.timestamp - 1000),
            TRANSFER_AMOUNT
        );
        uint256 expectedDecayedVotes = (TRANSFER_AMOUNT *
            (Constants.WAD - (DECAY_RATE * 1 days) / Constants.WAD)) /
            Constants.WAD;
        assertApproxEqRel(
            aSummerToken.getPastVotes(user2, block.timestamp - 1),
            expectedDecayedVotes,
            1e16
        );
    }

    // ======== Event tests ========

    function test_EmitsDelegateEvents() public {
        vm.expectEmit(true, true, true, true);
        emit DelegateChanged(user1, address(0), user2);

        vm.expectEmit(true, true, true, true);
        emit DelegateVotesChanged(user2, 0, TRANSFER_AMOUNT);

        vm.prank(user1);
        aSummerToken.delegate(user2);
    }

    function test_EmitsDecayUpdatedEvent() public {
        vm.prank(user1);
        aSummerToken.delegate(user2);

        vm.warp(block.timestamp + DECAY_FREE_WINDOW + 1 days);

        vm.expectEmit(true, true, true, true);
        emit DecayUpdated(
            user1,
            (Constants.WAD - (DECAY_RATE * 1 days) / Constants.WAD)
        );

        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user1);
    }
}
