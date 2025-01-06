// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerTokenTestBase} from "./SummerTokenTestBase.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {ISummerTokenErrors} from "../../src/errors/ISummerTokenErrors.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {console} from "forge-std/console.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract SummerTokenDecayTest is SummerTokenTestBase {
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    uint256 constant TRANSFER_AMOUNT = 1000 ether;
    Percentage constant YEARLY_DECAY_RATE = Percentage.wrap(0.1e18); // 10% per year
    Percentage constant EXCESSIVE_DECAY_RATE = Percentage.wrap(0.51e18); // 51% per year
    Percentage constant ALMOST_MAX_DECAY_RATE = Percentage.wrap(0.50e18); // 50% per year
    Percentage constant TOO_LOW_DECAY_RATE = Percentage.wrap(0.009e18); // 0.9% per year

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
        vm.warp(block.timestamp + INITIAL_DECAY_FREE_WINDOW + 1 days);

        // Force decay update
        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user1);

        // Calculate expected decay using yearly rate
        uint256 expectedVotes = (TRANSFER_AMOUNT *
            (Constants.WAD -
                (Percentage.unwrap(YEARLY_DECAY_RATE) * 1 days) /
                (365.25 days))) / Constants.WAD;

        assertApproxEqRel(aSummerToken.getVotes(user2), expectedVotes, 1e16); // 1% tolerance
    }

    function test_RevertWhenDecayRateTooHigh() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerTokenErrors.DecayRateTooHigh.selector,
                Percentage.unwrap(EXCESSIVE_DECAY_RATE)
            )
        );
        vm.prank(address(this));
        aSummerToken.setDecayRatePerYear(EXCESSIVE_DECAY_RATE);
    }

    function test_HistoricalVotingPower() public {
        // User 2 self-delegates because they intend to be a delegate
        // Also creates an initial checkpoint
        vm.prank(user2);
        aSummerToken.delegate(user2);

        vm.prank(user1);
        aSummerToken.delegate(user2);

        uint256 newTimestamp = block.timestamp +
            INITIAL_DECAY_FREE_WINDOW +
            1 days;
        vm.warp(newTimestamp);

        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user1);

        assertLt(aSummerToken.getVotes(user2), TRANSFER_AMOUNT * 2);

        assertEq(
            aSummerToken.getPastVotes(user2, block.timestamp - 1000),
            TRANSFER_AMOUNT * 2 // User 1 and User 2 both delegate to User 2
        );

        // Calculate expected decay using yearly rate
        uint256 expectedDecayedVotes = ((TRANSFER_AMOUNT * 2) *
            (Constants.WAD -
                (Percentage.unwrap(YEARLY_DECAY_RATE) * 1 days) /
                (365.25 days))) / Constants.WAD;

        assertApproxEqRel(
            aSummerToken.getPastVotes(user2, block.timestamp - 1),
            expectedDecayedVotes,
            1e16
        );
    }

    function test_HighButValidDecayRate() public {
        // Set decay rate to 50%
        vm.prank(address(this));
        aSummerToken.setDecayRatePerYear(ALMOST_MAX_DECAY_RATE);

        vm.prank(user1);
        aSummerToken.delegate(user2);

        // Move past decay free window and add significant time
        vm.warp(block.timestamp + INITIAL_DECAY_FREE_WINDOW + 180 days);

        // Force decay update
        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user1);

        // Calculate expected decay using 50% yearly rate over 180 days
        uint256 expectedVotes = (TRANSFER_AMOUNT *
            (Constants.WAD -
                (Percentage.unwrap(ALMOST_MAX_DECAY_RATE) * 180 days) /
                (365.25 days))) / Constants.WAD;

        // Should be approximately 75% of original amount (50% decay over half a year)
        assertApproxEqRel(aSummerToken.getVotes(user2), expectedVotes, 1e16); // 1% tolerance

        // Verify no underflow occurred and votes are still positive
        assertGt(aSummerToken.getVotes(user2), 0);
    }

    function test_MinimumValidDecayRate() public {
        // Set decay rate to exactly 1%
        Percentage minRate = Percentage.wrap(1e16);
        vm.prank(address(this));
        aSummerToken.setDecayRatePerYear(minRate);

        vm.prank(user1);
        aSummerToken.delegate(user2);

        // Move past decay free window and add significant time
        vm.warp(block.timestamp + INITIAL_DECAY_FREE_WINDOW + 180 days);

        // Force decay update
        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user1);

        // Calculate expected decay using 1% yearly rate over 180 days
        uint256 expectedVotes = (TRANSFER_AMOUNT *
            (Constants.WAD -
                (Percentage.unwrap(minRate) * 180 days) /
                (365.25 days))) / Constants.WAD;

        // Should be approximately 99.5% of original amount (1% decay over half a year)
        assertApproxEqRel(aSummerToken.getVotes(user2), expectedVotes, 1e16); // 1% tolerance

        // Verify votes are still very close to original amount
        assertGt(aSummerToken.getVotes(user2), (TRANSFER_AMOUNT * 99) / 100); // > 99% remaining
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

        vm.warp(block.timestamp + INITIAL_DECAY_FREE_WINDOW + 1 days);
        vm.roll(block.number + 1);

        uint256 expectedDecayFactor = aSummerToken.getDecayFactor(user1);

        vm.expectEmit(true, true, true, true);
        emit DecayUpdated(user1, expectedDecayFactor);

        vm.prank(address(aSummerToken));
        aSummerToken.updateDecayFactor(user1);
    }
}
