// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

contract SummerTimelockController is TimelockController {
    IProtocolAccessManager public immutable accessManager;

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin,
        address _accessManager
    ) TimelockController(minDelay, proposers, executors, admin) {
        accessManager = IProtocolAccessManager(_accessManager);
    }

    /**
     * @dev Override of the TimelockController's cancel function to support guardian-based cancellation.
     * @param id The identifier of the operation to cancel
     */
    function cancel(bytes32 id) public virtual override {
        // If caller has CANCELLER_ROLE and is a governor, allow without guardian check
        if (
            hasRole(CANCELLER_ROLE, msg.sender) &&
            accessManager.hasRole(accessManager.GOVERNOR_ROLE(), msg.sender)
        ) {
            super.cancel(id);
            return;
        }

        // For all other cancellers (including guardians with CANCELLER_ROLE),
        // require both the role AND active guardian status
        if (
            !hasRole(CANCELLER_ROLE, msg.sender) ||
            !accessManager.isActiveGuardian(msg.sender)
        ) {
            revert TimelockUnauthorizedCaller(msg.sender);
        }

        super.cancel(id);
    }
}
