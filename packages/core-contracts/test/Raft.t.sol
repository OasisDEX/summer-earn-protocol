// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import {IRaftEvents} from "../src/interfaces/IRaftEvents.sol";
import {Raft} from "../src/contracts/Raft.sol";

contract RaftTest is Test, IRaftEvents {
    Raft public raft;
    address public mockArk = address(5);
    address public mockSwapProvider = address(6);

    function setUp() public {
        raft = new Raft(mockSwapProvider);
    }

    function test_Harvest() public {
        address mockRewardToken = address(6);

        // Arrange
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk(mockArk).harvest.selector,
                mockRewardToken
            ),
            abi.encode()
        );

        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(mockArk, mockRewardToken);

        // Act
        raft.harvest(mockArk, mockRewardToken);
    }
}
