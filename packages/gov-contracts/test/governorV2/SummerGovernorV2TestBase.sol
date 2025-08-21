// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Origin, SummerGovernorV2} from "../../src/contracts/SummerGovernorV2.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";
import {SummerTokenTestBase} from "../token/SummerTokenTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IOAppSetPeer, TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {ISummerGovernor} from "../../src/interfaces/ISummerGovernor.sol";
import {ISummerGovernorV2} from "../../src/interfaces/ISummerGovernorV2.sol";
import {xSumr} from "../../src/contracts/xSumr.sol";
import {Staking} from "../../src/contracts/Staking.sol";

contract SummerGovernorV2TestBase is
    SummerTokenTestBase,
    ISummerGovernorErrors
{
    using OptionsBuilder for bytes;

    ExposedSummerGovernor public governorA;
    ExposedSummerGovernor public governorB;

    xSumr public axSumr;
    xSumr public bxSumr;
    Staking public aStaking;
    Staking public bStaking;

    uint48 public constant VOTING_DELAY = 1 days;
    uint32 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant PROPOSAL_THRESHOLD = 100000e18;
    uint256 public constant QUORUM_FRACTION = 4;

    address public alice = address(0x111);
    address public bob = address(0x112);
    address public charlie = address(0x113);
    address public david = address(0x114);
    address public guardian = address(0x115);
    address public whale = address(0x116);

    function setUp() public virtual override {
        initializeTokenTests();

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");
        vm.label(whale, "Whale");

        vm.label(address(aSummerToken), "chain a token");
        vm.label(address(bSummerToken), "chain b token");

        // Deploy xSumr tokens and staking contracts
        axSumr = new xSumr(address(accessManagerA));
        bxSumr = new xSumr(address(accessManagerB));

        aStaking = new Staking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr)
        );
        bStaking = new Staking(
            address(accessManagerB),
            address(bSummerToken),
            address(bxSumr)
        );

        // Set up staking modules
        vm.prank(address(timelockA));
        axSumr.setStakingModule(address(aStaking));

        vm.prank(address(timelockB));
        bxSumr.setStakingModule(address(bStaking));

        // Label the new contracts
        vm.label(address(axSumr), "chain a xSumr");
        vm.label(address(bxSumr), "chain b xSumr");
        vm.label(address(aStaking), "chain a staking");
        vm.label(address(bStaking), "chain b staking");

        SummerGovernorV2.GovernorParams memory paramsA = ISummerGovernorV2
            .GovernorParams({
                token: axSumr,
                timelock: timelockA,
                accessManager: address(accessManagerA),
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointA,
                hubChainId: 31337,
                initialOwner: address(timelockA)
            });
        SummerGovernorV2.GovernorParams memory paramsB = ISummerGovernorV2
            .GovernorParams({
                token: bxSumr,
                timelock: timelockB,
                accessManager: address(accessManagerB),
                votingDelay: VOTING_DELAY,
                votingPeriod: VOTING_PERIOD,
                proposalThreshold: PROPOSAL_THRESHOLD,
                quorumFraction: QUORUM_FRACTION,
                endpoint: lzEndpointB,
                hubChainId: 31337,
                initialOwner: address(timelockB)
            });
        governorA = new ExposedSummerGovernor(paramsA);
        governorB = new ExposedSummerGovernor(paramsB);

        vm.label(address(governorA), "SummerGovernorV2");
        vm.label(address(governorB), "SummerGovernorV2");

        vm.label(address(timelockA), "Timelock A");
        vm.label(address(timelockB), "Timelock B");

        vm.prank(owner);
        enableTransfers();
        changeTokensOwnership(address(timelockA), address(timelockB));

        timelockA.grantRole(timelockA.PROPOSER_ROLE(), address(governorA));
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(governorA));
        timelockB.grantRole(timelockB.PROPOSER_ROLE(), address(governorB));
        timelockB.grantRole(timelockB.CANCELLER_ROLE(), address(governorB));

        vm.prank(address(timelockA));
        aSummerToken.transfer(whale, 100_000_000e18);

        vm.prank(whale);
        aSummerToken.approve(address(aStaking), 100_000_000e18);

        // Stake tokens to get xSumr
        vm.prank(whale);
        aStaking.stake(whale, 100_000_000e18);

        // Delegate xSumr for voting
        vm.prank(whale);
        axSumr.delegate(whale);
        vm.prank(whale);
        bxSumr.delegate(whale);

        // Wire the governors (if needed)
        address[] memory governors = new address[](2);
        governors[0] = address(governorA);
        governors[1] = address(governorB);

        IOAppSetPeer aOApp = IOAppSetPeer(address(governorA));
        IOAppSetPeer bOApp = IOAppSetPeer(address(governorB));

        // Connect governorA to governorB
        // vm.prank(address(governorA));
        uint32 bEid_ = (bOApp.endpoint()).eid();
        vm.prank(address(timelockA));
        aOApp.setPeer(bEid_, addressToBytes32(address(bOApp)));

        // Connect governorB to governorA
        // vm.prank(address(governorB));
        uint32 aEid_ = (aOApp.endpoint()).eid();
        vm.prank(address(timelockB));
        bOApp.setPeer(aEid_, addressToBytes32(address(aOApp)));
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
        ) = createProposalParams(address(aSummerToken));

        // Add a unique identifier to the description to ensure unique proposals
        description = string(
            abi.encodePacked(description, " - ", block.number)
        );

        uint256 proposalId = governorA.propose(
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
    function createProposalParams(
        address tokenAddress
    )
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
        targets[0] = tokenAddress;
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

    function createAndExecuteProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal {
        // Give Alice enough tokens to meet proposal threshold through staking
        uint256 proposalThreshold = governorA.proposalThreshold();
        stakeAndGetXSumr(alice, proposalThreshold, true);

        // Create proposal
        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Give Alice enough additional tokens to meet quorum through staking
        uint256 quorumAmount = governorA.quorum(block.timestamp - 1);
        if (quorumAmount > proposalThreshold) {
            stakeAndGetXSumr(alice, quorumAmount - proposalThreshold, true);
        }

        advanceTimeForVotingDelay();

        // Vote on proposal
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        // Queue and execute the proposal
        governorA.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        advanceTimeForTimelockMinDelay();

        governorA.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
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

    // For immediate operations (propose, vote, etc)
    function advanceTimeAndBlock() internal {
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForPeriod(uint256 extraTime) internal {
        vm.warp(block.timestamp + extraTime);
        vm.roll(block.number + 1);
    }

    function advanceTimeForTimelockMinDelay() internal {
        vm.warp(block.timestamp + timelockA.getMinDelay() + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForVotingPeriod() internal {
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + 1);
    }

    function advanceTimeForVotingDelay() internal {
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + 1);
    }

    /*
     * @dev Helper function to stake SUMMER tokens and get xSumr tokens for voting
     * @param user The address that will receive the xSumr tokens
     * @param amount The amount of SUMMER tokens to stake
     * @param useChainA If true, use chain A contracts; if false, use chain B
     */
    function stakeAndGetXSumr(
        address user,
        uint256 amount,
        bool useChainA
    ) internal {
        if (useChainA) {
            // Transfer SUMMER tokens to user first
            vm.startPrank(address(timelockA));
            aSummerToken.transfer(user, amount);
            vm.stopPrank();

            // Approve staking contract to spend SUMMER tokens
            vm.prank(user);
            aSummerToken.approve(address(aStaking), amount);

            // Stake tokens to get xSumr
            vm.prank(user);
            aStaking.stake(user, amount);

            // Delegate xSumr for voting
            vm.prank(user);
            axSumr.delegate(user);
        } else {
            // Transfer SUMMER tokens to user first
            vm.startPrank(address(timelockB));
            bSummerToken.transfer(user, amount);
            vm.stopPrank();

            // Approve staking contract to spend SUMMER tokens
            vm.prank(user);
            bSummerToken.approve(address(bStaking), amount);

            // Stake tokens to get xSumr
            vm.prank(user);
            bStaking.stake(user, amount);

            // Delegate xSumr for voting
            vm.prank(user);
            bxSumr.delegate(user);
        }

        advanceTimeAndBlock();
    }

    /*
     * @dev Helper function to unstake xSumr tokens and get back SUMMER tokens
     * @param user The address that holds the xSumr tokens
     * @param amount The amount of xSumr tokens to unstake
     * @param useChainA If true, use chain A contracts; if false, use chain B
     */
    function unstakeTokens(
        address user,
        uint256 amount,
        bool useChainA
    ) internal {
        if (useChainA) {
            // Approve staking contract to spend xSumr tokens
            vm.prank(user);
            axSumr.approve(address(aStaking), amount);

            // Unstake tokens to get SUMMER back
            vm.prank(user);
            aStaking.unstake(user, amount);
        } else {
            // Approve staking contract to spend xSumr tokens
            vm.prank(user);
            bxSumr.approve(address(bStaking), amount);

            // Unstake tokens to get SUMMER back
            vm.prank(user);
            bStaking.unstake(user, amount);
        }
    }
}

contract ExposedSummerGovernor is SummerGovernorV2 {
    constructor(GovernorParams memory params) SummerGovernorV2(params) {}

    function exposedSendProposalToTargetChain(
        uint32 _dstEid,
        address[] memory _dstTargets,
        uint256[] memory _dstValues,
        bytes[] memory _dstCalldatas,
        bytes32 _dstDescriptionHash,
        bytes calldata _options
    ) public {
        _sendProposalToTargetChain(
            _dstEid,
            _dstTargets,
            _dstValues,
            _dstCalldatas,
            _dstDescriptionHash,
            _options
        );
    }

    // Test skipper function
    function test() public {}
}
