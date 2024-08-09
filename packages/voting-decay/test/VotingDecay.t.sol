// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/VotingDecay.sol";
import "../src/IVotingDecay.sol";

contract VotingDecayTest is Test {
    using VotingDecay for IVotingDecay.Account;

    mapping(address => IVotingDecay.Account) internal accounts;
    address internal user = address(1);
    uint256 internal constant INITIAL_VOTING_POWER = 1000e18;
    uint256 internal constant DECAY_RATE = 0.1e18; // 10% per year

    function setUp() public {
        IVotingDecay.Account storage account = accounts[user];
        account.votingPower = INITIAL_VOTING_POWER;
        account.lastUpdateTimestamp = block.timestamp;
        account.decayRate = DECAY_RATE;
        account.delegateTo = address(0);
    }

    function test_InitialVotingPower() public view {
        assertEq(VotingDecay.getCurrentVotingPower(accounts[user]), INITIAL_VOTING_POWER);
    }

    function test_DecayOverOneYear() public {
        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        uint256 expectedVotingPower = INITIAL_VOTING_POWER * 9 / 10; // 90% of initial
        assertApproxEqAbs(VotingDecay.getCurrentVotingPower(accounts[user]), expectedVotingPower, 1e18);
    }

    function test_UpdateDecay() public {
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        VotingDecay.updateDecay(accounts[user]);

        uint256 expectedVotingPower = INITIAL_VOTING_POWER * 95 / 100; // Roughly 95% of initial
        assertApproxEqAbs(accounts[user].votingPower, expectedVotingPower, 1e18);
        assertEq(accounts[user].lastUpdateTimestamp, block.timestamp);
    }

    function test_ResetDecay() public {
        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        VotingDecay.resetDecay(accounts[user]);

        assertEq(accounts[user].lastUpdateTimestamp, block.timestamp);
        assertEq(accounts[user].votingPower, INITIAL_VOTING_POWER); // Voting power shouldn't change on reset
    }

    function test_SetDecayRate() public {
        uint256 newRate = 0.2e18; // 20% per year
        VotingDecay.setDecayRate(accounts[user], newRate);
        assertEq(accounts[user].decayRate, newRate);
    }

    function testFail_SetInvalidDecayRate() public {
        uint256 invalidRate = 1.1e18; // 110% per year
        VotingDecay.setDecayRate(accounts[user], invalidRate);
    }

    function test_Delegate() public {
        address delegateAddress = address(2);
        IVotingDecay.Account storage delegateAccount = accounts[delegateAddress];

        VotingDecay.delegate(accounts[user], delegateAccount);

        assertEq(accounts[user].votingPower, 0);
        assertEq(accounts[user].delegateTo, delegateAddress);
        assertEq(delegateAccount.votingPower, INITIAL_VOTING_POWER);
    }

    function test_Undelegate() public {
        address delegateAddress = address(2);
        IVotingDecay.Account storage delegateAccount = accounts[delegateAddress];

        VotingDecay.delegate(accounts[user], delegateAccount);

        // Fast forward 6 months
        vm.warp(block.timestamp + 182 days);

        VotingDecay.undelegate(accounts[user], accounts);

        uint256 expectedVotingPower = INITIAL_VOTING_POWER * 95 / 100; // Roughly 95% of initial
        assertApproxEqAbs(accounts[user].votingPower, expectedVotingPower, 1e18);
        assertEq(accounts[user].delegateTo, address(0));
        assertEq(delegateAccount.votingPower, 0);
    }
}
