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
import {StakedSummerToken} from "../../src/contracts/StakedSummerToken.sol";
import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";

contract SummerGovernorV2TestBase is
    SummerTokenTestBase,
    ISummerGovernorErrors
{
    using OptionsBuilder for bytes;

    SummerGovernorV2 public governorA;
    SummerGovernorV2 public governorB;

    StakedSummerToken public axSumr;
    StakedSummerToken public bxSumr;
    MockERC20 public testToken;

    uint48 public constant VOTING_DELAY = 1 days;
    uint32 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant PROPOSAL_THRESHOLD = 10_000e18;
    uint256 public constant QUORUM_FRACTION = 40;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public david = makeAddr("david");
    address public guardian = makeAddr("guardian");
    address public whale = makeAddr("whale");

    address public foundation;
    SummerVestingWalletFactory public factoryVesting;
    SummerVestingWalletFactoryV2 public factoryVestingV2;

    function setUp() public virtual override {
        initializeTokenTests();

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");
        vm.label(whale, "Whale");

        foundation = makeAddr("foundation");

        vm.startPrank(address(timelockA));
        accessManagerA.grantFoundationRole(address(foundation));
        vm.stopPrank();

        // Deploy factory (foundation is initial owner)
        factoryVestingV2 = new SummerVestingWalletFactoryV2(
            address(aSummerToken),
            foundation
        );

        // Foundation has foundation role ( old vesting factory)
        factoryVesting = new SummerVestingWalletFactory(
            address(aSummerToken),
            address(accessManagerA)
        );

        // Deploy StakedSummerToken tokens and staking contracts
        axSumr = new StakedSummerToken(address(accessManagerA));
        bxSumr = new StakedSummerToken(address(accessManagerB));
        testToken = new MockERC20();

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
        governorA = new SummerGovernorV2(paramsA);
        governorB = new SummerGovernorV2(paramsB);

        vm.prank(owner);
        enableTransfers();
        changeTokensOwnership(address(timelockA), address(timelockB));

        timelockA.grantRole(timelockA.PROPOSER_ROLE(), address(governorA));
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(governorA));
        timelockB.grantRole(timelockB.PROPOSER_ROLE(), address(governorB));
        timelockB.grantRole(timelockB.CANCELLER_ROLE(), address(governorB));

        deal(
            address(testToken),
            whale,
            1000000000000000000000000000000000000000
        );
        deal(
            address(testToken),
            address(timelockA),
            1000000000000000000000000000000000000000
        );
        deal(
            address(testToken),
            address(timelockB),
            1000000000000000000000000000000000000000
        );

        // whale gets 100% of the StakedSummerToken supply
        vm.startPrank(address(timelockA));
        axSumr.addStakingModule(address(timelockA));
        axSumr.mint(whale, aSummerToken.totalSupply());
        vm.stopPrank();

        vm.startPrank(address(timelockB));
        bxSumr.addStakingModule(address(timelockB));
        bxSumr.mint(whale, bSummerToken.totalSupply());
        vm.stopPrank();

        // Wire the governors (if needed)
        address[] memory governors = new address[](2);
        governors[0] = address(governorA);
        governors[1] = address(governorB);

        IOAppSetPeer aOApp = IOAppSetPeer(address(governorA));
        IOAppSetPeer bOApp = IOAppSetPeer(address(governorB));

        // Connect governorA to governorB
        uint32 bEid_ = (bOApp.endpoint()).eid();
        vm.prank(address(timelockA));
        aOApp.setPeer(bEid_, addressToBytes32(address(bOApp)));

        // Connect governorB to governorA
        uint32 aEid_ = (aOApp.endpoint()).eid();
        vm.prank(address(timelockB));
        bOApp.setPeer(aEid_, addressToBytes32(address(aOApp)));

        advanceTimeAndBlock();

        vm.label(address(axSumr), "chain a StakedSummerToken");
        vm.label(address(bxSumr), "chain b StakedSummerToken");

        vm.label(address(governorA), "SummerGovernorV2");
        vm.label(address(governorB), "SummerGovernorV2");

        vm.label(address(timelockA), "Timelock A");
        vm.label(address(timelockB), "Timelock B");

        vm.label(address(aSummerToken), "chain a token");
        vm.label(address(bSummerToken), "chain b token");
        vm.label(address(testToken), "test token");
        vm.label(address(axSumr), "chain a StakedSummerToken");
        vm.label(address(bxSumr), "chain b StakedSummerToken");
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
        ) = createProposalParams(address(testToken));

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
     * @dev Helper function to stake SUMMER tokens and get StakedSummerToken tokens for voting
     * @param user The address that will receive the StakedSummerToken tokens
     * @param amount The amount of SUMMER tokens to stake
     * @param useChainA If true, use chain A contracts; if false, use chain B
     */
    function stakeAndGetXSumr(
        address user,
        uint256 amount,
        bool useChainA
    ) internal {
        if (useChainA) {
            // whale has 100% of the token supply
            vm.prank(whale);
            axSumr.burn(amount);

            vm.prank(address(timelockA));
            axSumr.mint(user, amount);

            // Delegate StakedSummerToken for voting
        } else {
            // Transfer SUMMER tokens to user first
            vm.prank(whale);
            bxSumr.burn(amount);

            vm.prank(address(timelockB));
            bxSumr.mint(user, amount);
        }

        advanceTimeAndBlock();
    }
}
