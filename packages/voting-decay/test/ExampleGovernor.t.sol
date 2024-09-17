// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ExampleGovernor} from "./ExampleGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {VotingDecayLibrary} from "../src/VotingDecayLibrary.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

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

contract ExampleGovernorTest is Test {
    MockERC20Votes public token;

    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    ExampleGovernor public governor;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public deployer = address(0x9);
    uint256 public constant INITIAL_VALUE = 100e18;
    uint40 internal constant INITIAL_DECAY_FREE_WINDOW = 30 days;
    // 0.1e18 per year is approximately 3.168808781402895e9 per second
    // (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE = 3.1709792e9; // ~10% per year

    function setUp() public {
        token = new MockERC20Votes();
        vm.label(address(token), "MockERC20Votes");

        vm.prank(deployer);
        governor = new ExampleGovernor(
            "Governor",
            IVotes(address(token)),
            INITIAL_DECAY_FREE_WINDOW,
            INITIAL_DECAY_RATE,
            VotingDecayLibrary.DecayFunction.Exponential
        );

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(address(governor), "Governor");
    }

    function test_Voting() public {
        deal(address(governor.token()), alice, governor.proposalThreshold());
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        (uint256 proposalId, ) = createProposal();

        vm.warp(block.timestamp + governor.votingDelay() + 1);
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, 1);
        vm.stopPrank();

        (, uint256 forVotes, ) = governor.proposalVotes(proposalId);
        assertEq(forVotes, INITIAL_VALUE);
        assertTrue(governor.hasVoted(proposalId, alice));
    }

    function test_ValueDecay() public {
        vm.startPrank(alice);
        // governor.registerVoter(INITIAL_VALUE);
        // uint256 initialValue = governor.getAggregateValue(alice);
        uint256 initialValue = 0;
        assertEq(initialValue, INITIAL_VALUE);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 decayedValue = 0;
        // uint256 decayedValue = governor.getAggregateValue(alice);
        assertLt(decayedValue, initialValue);
        assertGt(decayedValue, 0);
        vm.stopPrank();
    }

    function test_UpdateBaseValue() public {
        vm.startPrank(alice);
        // governor.registerVoter(INITIAL_VALUE);
        uint256 newValue = INITIAL_VALUE * 2;
        // governor.updateBaseValue(newValue);
        vm.stopPrank();

        uint256 baseValue = 0;
        // (uint256 baseValue, ) = governor.voters(alice);
        assertEq(baseValue, newValue);
    }

    function test_SetDecayRate() public {
        vm.startPrank(address(governor));
        // governor.registerVoter(INITIAL_VALUE);
        // Set a 5% annual decay rate
        uint256 newDecayRate = (uint256(1e18) / 20) / (365 * 24 * 60 * 60);
        governor.setDecayRatePerSecond(newDecayRate);
        vm.stopPrank();

        uint256 decayRatePerSecond = governor.decayRatePerSecond();
        assertEq(decayRatePerSecond, newDecayRate);
    }

    function test_SetDecayFreeWindow() public {
        vm.startPrank(address(governor));
        // governor.registerVoter(INITIAL_VALUE);
        uint40 newWindow = 60 days;
        governor.setDecayFreeWindow(newWindow);
        vm.stopPrank();

        uint40 decayFreeWindow = governor.decayFreeWindow();
        assertEq(decayFreeWindow, newWindow);
    }

    function test_SetDecayFunction() public {
        vm.startPrank(address(governor));
        // governor.registerVoter(INITIAL_VALUE);
        governor.setDecayFunction(VotingDecayLibrary.DecayFunction.Exponential);
        vm.stopPrank();

        VotingDecayLibrary.DecayFunction decayFunction = governor
            .decayFunction();
        assertEq(
            uint8(decayFunction),
            uint8(VotingDecayLibrary.DecayFunction.Exponential)
        );
    }

    function test_CompareDecayFunctions() public {
        uint256 alicePrivateKey = 0xa11ce;
        address aliceAddress = vm.addr(alicePrivateKey);
        vm.label(aliceAddress, "Alice");

        deal(address(token), aliceAddress, 1e12);

        vm.prank(address(deployer));
        // Set linear decay
        governor.setDecayFunction(VotingDecayLibrary.DecayFunction.Linear);
        vm.warp(block.timestamp + 60 days);
        vm.roll(5184001);

        uint256 linearDecayedValue = governor.getVotes(
            aliceAddress,
            block.timestamp - 1
        );

        // Reset decay and set exponential decay
        vm.startPrank(address(deployer));
        // governor.resetDecay(aliceAddress);
        governor.setDecayFunction(VotingDecayLibrary.DecayFunction.Exponential);
        vm.stopPrank();

        vm.warp(block.timestamp + 60 days);
        vm.roll(10368001);

        uint256 exponentialDecayedValue = governor.getVotes(
            aliceAddress,
            block.timestamp - 1
        );

        // Exponential decay should result in a higher value than linear decay after 120 days
        assertGt(exponentialDecayedValue, linearDecayedValue);

        // Ensure the votes are less than the initial amount
        assertLt(linearDecayedValue, 1e12);
        assertLt(exponentialDecayedValue, 1e12);
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

        // Add a unique identifier to the description to ensure unique proposals
        description = string(
            abi.encodePacked(description, " - ", block.number)
        );

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
        targets[0] = address(governor.token());
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
