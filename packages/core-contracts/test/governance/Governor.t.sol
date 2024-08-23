// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/contracts/Governor.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract MockERC20Votes is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("Mock Token", "MTK") ERC20Permit("Mock Token") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    // Override the nonces function to resolve the conflict
    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner); // Or choose one of the base implementations explicitly
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }
}

contract SummerEarnGovernorTest is Test {
    SummerEarnGovernor public governor;
    MockERC20Votes public token;
    TimelockController public timelock;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    uint256 public constant INITIAL_SUPPLY = 1000000e18;
    uint48 public constant VOTING_DELAY = 1;
    uint32 public constant VOTING_PERIOD = 50400;
    uint256 public constant PROPOSAL_THRESHOLD = 10000e18;
    uint256 public constant QUORUM_FRACTION = 4;

    function setUp() public {
        token = new MockERC20Votes();
        token.mint(alice, INITIAL_SUPPLY);

        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(
            1 days,
            proposers,
            executors,
            address(this)
        );

        governor = new SummerEarnGovernor(
            IVotes(address(token)),
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_FRACTION
        );

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        vm.prank(alice);
        token.delegate(alice);
    }

    function test_InitialSetup() public view {
        assertEq(governor.name(), "SummerEarnGovernor");
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governor.quorumNumerator(), QUORUM_FRACTION);
    }

    function test_ProposalCreation() public {
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();
        assertGt(proposalId, 0);
    }

    function test_Voting() public {
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes, ) = governor.proposalVotes(proposalId);
        assertEq(forVotes, INITIAL_SUPPLY);
    }

    function test_ProposalExecution() public {
        vm.prank(alice);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams();
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        assertEq(token.balanceOf(bob), 100);
    }

    function test_Whitelisting() public {
        vm.prank(address(timelock));
        governor.setWhitelistAccountExpiration(
            charlie,
            block.timestamp + 1 days
        );

        assertTrue(governor.isWhitelisted(charlie));

        vm.prank(charlie);
        (uint256 proposalId, ) = createProposal();
        assertGt(proposalId, 0);
    }

    function test_ProposalCancellation() public {
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        vm.prank(address(timelock));
        governor.setWhitelistGuardian(bob);

        vm.prank(bob);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams();
        governor.cancel(
            targets,
            values,
            calldatas,
            hashDescription(description)
        );

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Canceled)
        );
    }

    function createProposal() internal returns (uint256, bytes32) {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = createProposalParams();
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        return (proposalId, hashDescription(description));
    }

    function createProposalParams()
        internal
        view
        returns (
            address[] memory,
            uint256[] memory,
            bytes[] memory,
            string memory
        )
    {
        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            bob,
            100
        );
        string memory description = "Transfer 100 tokens to Bob";

        return (targets, values, calldatas, description);
    }

    function hashDescription(
        string memory description
    ) internal pure returns (bytes32) {
        return keccak256(bytes(description));
    }
}
