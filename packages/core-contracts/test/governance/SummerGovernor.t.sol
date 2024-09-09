// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/contracts/SummerGovernor.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/*
 * @title MockERC20Votes
 * @dev A mock ERC20 token with voting capabilities for testing purposes.
 */
contract MockERC20Votes is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("Mock Token", "MTK") ERC20Permit("Mock Token") {}

    /*
     * @dev Mints tokens to a specified address.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /*
     * @dev Overrides the nonces function to resolve conflicts between ERC20Permit and Nonces.
     * @param owner The address to check nonces for.
     * @return The current nonce for the given address.
     */
    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /*
     * @dev Internal function to update token balances.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }
}

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernor functionality.
 */
contract SummerGovernorTest is Test, ISummerGovernorErrors {
    SummerGovernor public governor;
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

    /*
     * @dev Sets up the test environment.
     */
    function setUp() public {
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");

        token = new MockERC20Votes();
        vm.label(address(token), "MockERC20Votes");
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
        vm.label(address(timelock), "TimelockController");

        SummerGovernor.GovernorParams memory params = SummerGovernor
            .GovernorParams({
                token: IVotes(address(token)),
                timelock: timelock,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION
            });

        governor = new SummerGovernor(params);
        vm.label(address(governor), "SummerGovernor");

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        vm.prank(alice);
        token.delegate(alice);
    }

    /*
     * @dev Tests the initial setup of the governor.
     */
    function test_InitialSetup() public view {
        assertEq(governor.name(), "SummerGovernor");
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governor.quorumNumerator(), QUORUM_FRACTION);
    }

    /*
     * @dev Tests the proposal creation process.
     */
    function test_ProposalCreation() public {
        deal(address(token), alice, governor.proposalThreshold());
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        assertGt(proposalId, 0);
    }

    /*
     * @dev Tests the voting process on a proposal.
     */
    function test_Voting() public {
        deal(address(token), alice, governor.proposalThreshold());
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes, ) = governor.proposalVotes(proposalId);
        assertEq(forVotes, INITIAL_SUPPLY);
    }

    /*
     * @dev Tests the full proposal execution flow.
     * This test covers:
     * 1. Setting up initial token balances
     * 2. Creating a proposal
     * 3. Voting on the proposal
     * 4. Queueing the proposal
     * 5. Executing the proposal
     * 6. Verifying the result of the execution
     */
    function test_ProposalExecution() public {
        deal(address(token), address(timelock), 100);
        deal(address(token), alice, governor.proposalThreshold());
        vm.roll(block.number + governor.votingDelay() + 1);

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

    /*
     * @dev Tests the whitelisting process through a governance proposal.
     */
    function test_Whitelisting() public {
        address account = address(0x03);
        uint256 expiration = block.timestamp + 10 days;

        uint256 proposalThreshold = governor.proposalThreshold();

        vm.prank(address(token));
        deal(address(token), alice, proposalThreshold);

        vm.startPrank(alice);
        token.delegate(alice);
        vm.roll(block.number + 1);
        vm.stopPrank();

        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistAccountExpiration.selector,
            account,
            expiration
        );
        string memory description = "Whitelist account proposal";

        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        uint256 votingDelay = governor.votingDelay();
        vm.warp(block.timestamp + votingDelay + 1);
        vm.roll(block.number + votingDelay + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);

        uint256 votingPeriod = governor.votingPeriod();
        vm.warp(block.timestamp + votingPeriod + 1);
        vm.roll(block.number + votingPeriod + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        uint256 timelockDelay = timelock.getMinDelay();
        vm.warp(block.timestamp + timelockDelay + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        bool isWhitelisted = governor.isWhitelisted(account);
        uint256 actualExpiration = governor.getWhitelistAccountExpiration(
            account
        );

        assertTrue(isWhitelisted, "Account should be whitelisted");
        assertEq(
            actualExpiration,
            expiration,
            "Expiration timestamp should match"
        );
    }

    /*
     * @dev Tests the proposal cancellation process.
     */
    function test_ProposalCancellation() public {
        deal(address(token), alice, governor.proposalThreshold());

        vm.startPrank(alice);
        token.delegate(alice);
        vm.roll(block.number + 1); // Move to next block to activate voting power

        // Create proposal to set Bob as whitelist guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistGuardian.selector,
            bob
        );
        string memory description = "Set Bob as whitelist guardian";

        uint256 guardianProposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(guardianProposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.stopPrank();

        // Now Bob is the whitelist guardian, create a proposal to cancel
        vm.startPrank(alice);
        (uint256 proposalId, ) = createProposal();
        vm.stopPrank();

        // Assert that Bob is indeed the whitelist guardian
        assertEq(
            governor.getWhitelistGuardian(),
            bob,
            "Bob should be the whitelist guardian"
        );

        vm.prank(bob);
        (
            address[] memory cancelTargets,
            uint256[] memory cancelValues,
            bytes[] memory cancelCalldatas,
            string memory cancelDescription
        ) = createProposalParams();
        governor.cancel(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            hashDescription(cancelDescription)
        );

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Canceled)
        );
    }

    function test_PauseUnpauseOnlyGovernance() public {
        vm.prank(address(alice));
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorOnlyExecutor.selector,
                address(alice)
            )
        );
        governor.pause();

        vm.prank(address(alice));
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorOnlyExecutor.selector,
                address(alice)
            )
        );
        governor.unpause();
    }

    function test_SupportsInterface() public view {
        assertTrue(governor.supportsInterface(type(IGovernor).interfaceId));
        assertFalse(governor.supportsInterface(0xffffffff));
    }

    function test_ProposalThreshold() public view {
        uint256 threshold = governor.proposalThreshold();
        assertGe(threshold, governor.MIN_PROPOSAL_THRESHOLD());
        assertLe(threshold, governor.MAX_PROPOSAL_THRESHOLD());
    }

    function test_SetProposalThresholdOutOfBounds() public {
        uint256 belowMin = governor.MIN_PROPOSAL_THRESHOLD() - 1;
        uint256 aboveMax = governor.MAX_PROPOSAL_THRESHOLD() + 1;

        SummerGovernor.GovernorParams memory params = SummerGovernor
            .GovernorParams({
                token: IVotes(address(token)),
                timelock: timelock,
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: belowMin,
                quorumFraction: QUORUM_FRACTION
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                belowMin,
                governor.MIN_PROPOSAL_THRESHOLD(),
                governor.MAX_PROPOSAL_THRESHOLD()
            )
        );
        new SummerGovernor(params);

        params.proposalThreshold = aboveMax;
        vm.expectRevert(
            abi.encodeWithSelector(
                SummerGovernorInvalidProposalThreshold.selector,
                aboveMax,
                governor.MIN_PROPOSAL_THRESHOLD(),
                governor.MAX_PROPOSAL_THRESHOLD()
            )
        );
        new SummerGovernor(params);
    }

    function test_ProposalCreationWhitelisted() public {
        address whitelistedUser = address(0x1234);
        uint256 expiration = block.timestamp + 10 days;

        // Ensure Alice has enough voting power
        uint256 proposalThreshold = governor.proposalThreshold();
        deal(address(token), alice, proposalThreshold);

        vm.startPrank(alice);
        token.delegate(alice);
        vm.roll(block.number + 1); // Move to next block to activate voting power
        vm.stopPrank();

        // Create and execute a proposal to set the whitelist account expiration
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistAccountExpiration.selector,
            whitelistedUser,
            expiration
        );
        string memory description = "Set whitelist account expiration";

        vm.prank(alice);
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

        vm.prank(alice);
        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        vm.prank(bob);
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Ensure the whitelisted user has no voting power
        vm.prank(whitelistedUser);
        token.delegate(address(0));

        // Verify that the user is whitelisted
        assertTrue(
            governor.isWhitelisted(whitelistedUser),
            "User should be whitelisted"
        );

        // Now create a proposal as the whitelisted user
        vm.startPrank(whitelistedUser);
        (uint256 anotherProposalId, ) = createProposal();
        vm.stopPrank();

        // Verify that the proposal was created successfully
        assertTrue(
            anotherProposalId > 0,
            "Proposal should be created successfully"
        );
        assertEq(
            uint(governor.state(anotherProposalId)),
            uint(IGovernor.ProposalState.Pending),
            "Proposal should be in Pending state"
        );
    }

    function test_CancelProposalByGuardian() public {
        deal(address(token), alice, governor.proposalThreshold());
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();

        address guardian = address(0x5678);

        // Create and execute a proposal to set the whitelist guardian
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            SummerGovernor.setWhitelistGuardian.selector,
            guardian
        );
        string memory description = "Set whitelist guardian";

        vm.prank(alice);
        uint256 guardianProposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(guardianProposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Now cancel the original proposal as the guardian
        (
            address[] memory cancelTargets,
            uint256[] memory cancelValues,
            bytes[] memory cancelCalldatas,

        ) = createProposalParams();

        vm.prank(guardian);
        governor.cancel(
            cancelTargets,
            cancelValues,
            cancelCalldatas,
            descriptionHash
        );

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Canceled)
        );
    }

    function test_PauseAndUnpause() public {
        // Ensure Alice has enough voting power
        uint256 proposalThreshold = governor.proposalThreshold();
        deal(address(token), alice, proposalThreshold);

        vm.startPrank(alice);
        token.delegate(alice);
        vm.roll(block.number + 1); // Move to next block to activate voting power
        vm.stopPrank();

        // Create and execute a proposal to pause the contract
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(SummerGovernor.pause.selector);
        string memory description = "Pause the contract";

        vm.prank(alice);
        uint256 pauseProposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(pauseProposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        assertTrue(governor.paused());

        // Create and execute a proposal to unpause the contract
        calldatas[0] = abi.encodeWithSelector(SummerGovernor.unpause.selector);
        description = "Unpause the contract";

        vm.prank(alice);
        uint256 unpauseProposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(unpauseProposalId, 1);

        vm.warp(block.timestamp + governor.votingPeriod() + 1);
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        assertFalse(governor.paused());
    }

    function test_CancelProposalByProposer() public {
        deal(address(token), alice, governor.proposalThreshold());
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        (uint256 proposalId, bytes32 descriptionHash) = createProposal();
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,

        ) = createProposalParams();

        governor.cancel(targets, values, calldatas, descriptionHash);
        vm.stopPrank();

        assertEq(
            uint(governor.state(proposalId)),
            uint(IGovernor.ProposalState.Canceled)
        );
    }

    /*
     * @dev Creates a proposal for testing purposes.
     * @return proposalId The ID of the created proposal.
     * @return descriptionHash The hash of the proposal description.
     */
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

    /*
     * @dev Creates parameters for a proposal.
     * @return targets The target addresses for the proposal.
     * @return values The values to be sent with the proposal.
     * @return calldatas The function call data for the proposal.
     * @return description The description of the proposal.
     */
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

    /*
     * @dev Hashes the description of a proposal.
     * @param description The description to hash.
     * @return The keccak256 hash of the description.
     */
    function hashDescription(
        string memory description
    ) internal pure returns (bytes32) {
        return keccak256(bytes(description));
    }
}
