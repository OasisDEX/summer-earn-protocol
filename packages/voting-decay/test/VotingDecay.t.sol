// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/VotingDecay.sol";
import "../src/IVotingDecay.sol";

contract VotingDecayTest is Test {
    using VotingDecay for IVotingDecay.Account;

    IVotingDecay.Account internal account;
    address internal user = address(1);
    uint256 internal constant INITIAL_VOTING_POWER = 1000e18;
    uint256 internal constant DECAY_RATE = 0.1e18; // 10% per year

    function setUp() public {
        account.votingPower = INITIAL_VOTING_POWER;
        account.lastUpdateTimestamp = block.timestamp;
        account.decayRate = DECAY_RATE;
        account.delegate = address(0);
    }

    function testInitialVotingPower() public {
        assertEq(account.getCurrentVotingPower(), INITIAL_VOTING_POWER);
    }

    function testDecayOverOneYear() public {
        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        uint256 expectedVotingPower = INITIAL_VOTING_POWER * 9 / 10; // 90% of initial
        assertApproxEqAbs(account.getCurrentVotingPower(), expectedVotingPower, 1e18);
    }

    function testUpdateDecay() public {
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        account.updateDecay();

        uint256 expectedVotingPower = INITIAL_VOTING_POWER * 95 / 100; // Roughly 95% of initial
        assertApproxEqAbs(account.votingPower, expectedVotingPower, 1e18);
        assertEq(account.lastUpdateTimestamp, block.timestamp);
    }

    function testResetDecay() public {
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        account.resetDecay();

        assertEq(account.lastUpdateTimestamp, block.timestamp);
        assertEq(account.votingPower, INITIAL_VOTING_POWER); // Voting power shouldn't change on reset
    }

    function testSetDecayRate() public {
        uint256 newRate = 0.2e18; // 20% per year
        account.setDecayRate(newRate);
        assertEq(account.decayRate, newRate);
    }

    function testFailSetInvalidDecayRate() public {
        uint256 invalidRate = 1.1e18; // 110% per year
        account.setDecayRate(invalidRate);
    }

    function testDelegate() public {
        IVotingDecay.Account storage delegateAccount = accounts[address(2)];
        account.delegate(delegateAccount);

        assertEq(account.votingPower, 0);
        assertEq(account.delegate, address(delegateAccount));
        assertEq(delegateAccount.votingPower, INITIAL_VOTING_POWER);
    }

    function testUndelegate() public {
        IVotingDecay.Account storage delegateAccount = accounts[address(2)];
        account.delegate(delegateAccount);

        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        account.undelegate();

        uint256 expectedVotingPower = INITIAL_VOTING_POWER * 95 / 100; // Roughly 95% of initial
        assertApproxEqAbs(account.votingPower, expectedVotingPower, 1e18);
        assertEq(account.delegate, address(0));
        assertEq(delegateAccount.votingPower, 0);
    }

    // Helper function to simulate multiple accounts
    mapping(address => IVotingDecay.Account) accounts;
}
