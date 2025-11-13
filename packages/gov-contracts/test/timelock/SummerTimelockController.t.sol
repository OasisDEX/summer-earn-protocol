// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

// Reuse the existing test base that deploys ExposedSummerTimelockController, AccessManager, etc.
import {SummerTokenTestBase, ExposedSummerTimelockController} from "../token/SummerTokenTestBase.sol";

contract SummerTimelockControllerTest is SummerTokenTestBase {
    function test_schedule_marksGuardianExpiryOperation() public {
        address target = address(accessManagerA);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            IProtocolAccessManager.setGuardianExpiration.selector,
            makeAddr("guardianA"),
            block.timestamp + 30 days
        );
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt-A");

        // As test contract we have PROPOSER_ROLE per base setup
        timelockA.schedule(target, value, data, predecessor, salt, 1 days);

        bytes32 id = timelockA.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );
        bool flagged = timelockA.exposedIsGuardianExpiryProposal(id);
        assertTrue(flagged, "guardian expiry op should be flagged");
    }

    function test_cancel_expiry_onlyGovernorsCanCancel_revertsForNonGovernor()
        public
    {
        address guardian = makeAddr("guardianB");
        // Prepare guardian-expiry operation
        address target = address(accessManagerA);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            IProtocolAccessManager.setGuardianExpiration.selector,
            guardian,
            block.timestamp + 30 days
        );
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt-B");
        timelockA.schedule(target, value, data, predecessor, salt, 1 days);
        bytes32 id = timelockA.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );

        // Give some unrelated permissions to the caller (CANCELLER_ROLE), but NOT governor
        address caller = makeAddr("notGovernor");
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), caller);

        // Attempt to cancel should revert with the explicit message
        vm.prank(caller);
        vm.expectRevert(
            bytes("Only governors can cancel guardian expiry proposals")
        );
        timelockA.cancel(id);

        vm.prank(guardian);
        vm.expectRevert(
            bytes("Only governors can cancel guardian expiry proposals")
        );
        timelockA.cancel(id);
    }

    function test_cancel_expiry_governorCanCancel_succeeds() public {
        address guardian = makeAddr("guardianC");
        address target = address(accessManagerA);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            IProtocolAccessManager.setGuardianExpiration.selector,
            guardian,
            block.timestamp + 45 days
        );
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt-C");
        timelockA.schedule(target, value, data, predecessor, salt, 1 days);
        bytes32 id = timelockA.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );

        // Ensure timelock has CANCELLER_ROLE for OZ TimelockController cancel
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(timelockA));

        // The timelock itself has GOVERNOR_ROLE in accessManagerA per base setup
        vm.prank(address(timelockA));
        timelockA.cancel(id);

        // Canceling twice should fail in OZ Timelock (no operation to cancel)
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature(
                "TimelockUnexpectedOperationState(bytes32,bytes32)",
                id,
                6
            )
        );
        timelockA.cancel(id);
    }

    function test_cancel_nonExpiry_governorWithCancellerRole_branch() public {
        // Create a non-expiry operation (e.g., a benign view call payload)
        bytes32 role = accessManagerA.GOVERNOR_ROLE();
        address account = address(this);
        address target = address(accessManagerA);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            IProtocolAccessManager.hasRole.selector,
            role,
            account
        );
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt-D");
        timelockA.schedule(target, value, data, predecessor, salt, 1 days);
        bytes32 id = timelockA.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );

        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(timelockA));

        // This exercises the _isGovernorWithCancelRole branch
        vm.prank(address(timelockA));
        timelockA.cancel(id);
    }

    function test_cancel_nonExpiry_guardianWithCancelRole() public {
        address guardian = makeAddr("guardianE");
        // Create a non-expiry operation (e.g., a benign view call payload)
        bytes32 role = accessManagerA.GOVERNOR_ROLE();
        address account = address(this);
        address target = address(accessManagerA);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            IProtocolAccessManager.hasRole.selector,
            role,
            account
        );
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt-D");
        timelockA.schedule(target, value, data, predecessor, salt, 1 days);
        bytes32 id = timelockA.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );
        vm.startPrank(address(timelockA));
        accessManagerA.grantGuardianRole(guardian);
        accessManagerA.setGuardianExpiration(
            guardian,
            block.timestamp + 1000000
        );
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), address(guardian));
        vm.stopPrank();

        // This exercises the fallback branch
        vm.prank(address(guardian));
        timelockA.cancel(id);
    }

    function test_cancel_nonExpiry_nonGuardianNonGovernorWithCancellerRole_revertsUnauthorized()
        public
    {
        // Non-expiry operation
        address target = address(accessManagerA);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(
            IProtocolAccessManager.hasRole.selector,
            accessManagerA.GOVERNOR_ROLE(),
            address(this)
        );
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt-E");
        timelockA.schedule(target, value, data, predecessor, salt, 1 days);
        bytes32 id = timelockA.hashOperation(
            target,
            value,
            data,
            predecessor,
            salt
        );

        // Give CANCELLER_ROLE but no guardian or governor status
        address caller = makeAddr("randomCanceller");
        timelockA.grantRole(timelockA.CANCELLER_ROLE(), caller);

        // Expect OZ TimelockUnauthorizedCaller error
        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSignature(
                "TimelockUnauthorizedCaller(address)",
                caller
            )
        );
        timelockA.cancel(id);
    }

    function test_scheduleBatch_marksGuardianExpiryOperation() public {
        address target0 = address(accessManagerA);
        address target1 = address(accessManagerA);
        address[] memory targets = new address[](2);
        targets[0] = target0;
        targets[1] = target1;

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        bytes[] memory payloads = new bytes[](2);
        payloads[0] = abi.encodeWithSelector(
            IProtocolAccessManager.hasRole.selector,
            accessManagerA.GOVERNOR_ROLE(),
            address(this)
        );
        payloads[1] = abi.encodeWithSelector(
            IProtocolAccessManager.setGuardianExpiration.selector,
            makeAddr("guardianD"),
            block.timestamp + 60 days
        );

        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt-F");
        timelockA.scheduleBatch(
            targets,
            values,
            payloads,
            predecessor,
            salt,
            1 days
        );

        bytes32 id = timelockA.hashOperationBatch(
            targets,
            values,
            payloads,
            predecessor,
            salt
        );
        bool flagged = timelockA.exposedIsGuardianExpiryProposal(id);
        assertTrue(flagged, "batch should be flagged as guardian expiry op");
    }
}
