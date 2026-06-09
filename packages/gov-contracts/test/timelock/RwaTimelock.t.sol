// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RwaTimelock} from "../../src/contracts/RwaTimelock.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @dev Minimal target whose `bump()` is gated to a single authorized caller (the timelock).
contract Bumpable {
    address public immutable authorized;
    uint256 public value;

    error NotAuthorized();

    constructor(address authorized_) {
        authorized = authorized_;
    }

    function bump(uint256 newValue) external {
        if (msg.sender != authorized) revert NotAuthorized();
        value = newValue;
    }
}

contract RwaTimelockTest is Test {
    address internal proposer = makeAddr("proposer");
    address internal stranger = makeAddr("stranger");

    bytes32 internal constant PREDECESSOR = bytes32(0);
    bytes32 internal constant SALT = keccak256("rwa-salt");

    function setUp() public {
        // Foundry's default block.timestamp is 1, which collides with TimelockController's
        // _DONE_TIMESTAMP sentinel (1) and makes a zero-delay operation read as not-ready. Warp to
        // a realistic timestamp so the contract behaves as it would on-chain.
        vm.warp(1_000_000);
    }

    function _deploy(uint256 delay) internal returns (RwaTimelock tl) {
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = address(0); // open execution
        tl = new RwaTimelock(delay, proposers, executors, address(0));
    }

    function _bumpCall(uint256 newValue) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(Bumpable.bump.selector, newValue);
    }

    /// @notice With a zero delay an operation can be scheduled and executed in the same block.
    function test_zeroDelay_executesImmediately() public {
        RwaTimelock tl = _deploy(0);
        Bumpable target = new Bumpable(address(tl));
        bytes memory data = _bumpCall(42);

        vm.prank(proposer);
        tl.schedule(address(target), 0, data, PREDECESSOR, SALT, 0);

        // Ready in the same block — anyone (open executor) can execute right away.
        vm.prank(stranger);
        tl.execute(address(target), 0, data, PREDECESSOR, SALT);

        assertEq(target.value(), 42);
    }

    /// @notice A non-zero delay blocks execution until the delay has elapsed, then allows it.
    function test_nonZeroDelay_enforcesWait() public {
        uint256 delay = 2 days;
        RwaTimelock tl = _deploy(delay);
        Bumpable target = new Bumpable(address(tl));
        bytes memory data = _bumpCall(7);

        vm.prank(proposer);
        tl.schedule(address(target), 0, data, PREDECESSOR, SALT, delay);

        // Too early: executing before the delay reverts.
        vm.prank(stranger);
        vm.expectRevert();
        tl.execute(address(target), 0, data, PREDECESSOR, SALT);

        // After the delay it succeeds.
        vm.warp(block.timestamp + delay);
        vm.prank(stranger);
        tl.execute(address(target), 0, data, PREDECESSOR, SALT);

        assertEq(target.value(), 7);
    }

    /// @notice Only proposers may schedule.
    function test_onlyProposerCanSchedule() public {
        RwaTimelock tl = _deploy(0);
        Bumpable target = new Bumpable(address(tl));
        bytes memory data = _bumpCall(1);

        vm.prank(stranger);
        vm.expectRevert();
        tl.schedule(address(target), 0, data, PREDECESSOR, SALT, 0);
    }

    /// @notice The deployed minimum delay is reported by the timelock.
    function test_minDelayReflectsConstructorArg() public {
        RwaTimelock tl = _deploy(3 days);
        assertEq(tl.getMinDelay(), 3 days);
    }
}
