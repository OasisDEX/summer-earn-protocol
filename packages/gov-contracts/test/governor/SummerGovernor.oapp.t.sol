// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IOAppSetPeer} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract SummerGovernorOAppTest is SummerGovernorTestBase {
    using OptionsBuilder for bytes;

    address internal voter = address(0x123);
    address[] internal targets;
    uint256[] internal values;
    bytes[] internal calldatas;
    string internal description;

    function createBasicProposal()
        internal
        returns (
            address[] memory _targets,
            uint256[] memory _values,
            bytes[] memory _calldatas,
            string memory _description
        )
    {
        targets = new address[](1);
        targets[0] = address(0x123);

        values = new uint256[](1);
        values[0] = 0;

        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("doSomething()");

        description = "Test Proposal";

        return (targets, values, calldatas, description);
    }

    function createAndPassProposal()
        internal
        returns (uint256 proposalId, bytes32 descriptionHash)
    {
        (
            address[] memory _targets,
            uint256[] memory _values,
            bytes[] memory _calldatas,
            string memory _description
        ) = createBasicProposal();

        descriptionHash = keccak256(bytes(_description));
        proposalId = governorA.propose(
            _targets,
            _values,
            _calldatas,
            _description
        );

        // Fast forward past voting delay
        vm.roll(block.number + governorA.votingDelay() + 1);

        // Cast votes
        vm.prank(voter);
        governorA.castVote(proposalId, 1);

        // Fast forward past voting period
        vm.roll(block.number + governorA.votingPeriod() + 1);

        return (proposalId, descriptionHash);
    }

    function test_SetPeer() public {
        uint32 newEid = 123;
        address newPeer = address(0x123);

        vm.prank(address(timelockA));
        governorA.setPeer(newEid, addressToBytes32(newPeer));

        assertEq(governorA.peers(newEid), addressToBytes32(newPeer));
    }

    function test_SetPeerOnlyOwner() public {
        uint32 newEid = 123;
        address newPeer = address(0x123);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                alice
            )
        );
        governorA.setPeer(newEid, addressToBytes32(newPeer));
    }
}
