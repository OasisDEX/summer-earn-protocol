// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

contract SummerTimelockController is TimelockController {
    IProtocolAccessManager public immutable accessManager;

    // Add mapping to track guardian expiry operations
    mapping(bytes32 => bool) private _guardianExpiryOperations;

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
     * @dev Override of the TimelockController's cancel function to support guardian-based cancellation
     * with special handling for guardian expiry proposals.
     *
     * Cancellation rules:
     * 1. Guardian expiry proposals can ONLY be cancelled by governors
     * 2. Governors with cancel role can cancel any other proposal
     * 3. Active guardians with cancel role can cancel any non-expiry proposal
     *
     * @param id The identifier of the operation to cancel
     */
    function cancel(bytes32 id) public virtual override {
        if (_isGuardianExpiryProposal(id)) {
            require(
                accessManager.hasRole(
                    accessManager.GOVERNOR_ROLE(),
                    msg.sender
                ),
                "Only governors can cancel guardian expiry proposals"
            );
            super.cancel(id);
            return;
        }

        if (_isGovernorWithCancelRole(msg.sender)) {
            super.cancel(id);
            return;
        }

        if (!_isActiveGuardianWithCancelRole(msg.sender)) {
            revert TimelockUnauthorizedCaller(msg.sender);
        }

        super.cancel(id);
    }

    /**
     * @dev Checks if the provided operation data corresponds to a guardian expiry proposal.
     *
     * Guardian expiry proposals are special operations that set the expiration time for guardians.
     * These proposals have additional restrictions on who can cancel them to prevent guardians
     * from blocking their own expiry mechanisms.
     *
     * @return bool True if the operation is a guardian expiry proposal
     */
    function _isGuardianExpiryProposal(
        bytes32 id
    ) internal view returns (bool) {
        return _guardianExpiryOperations[id];
    }

    /**
     * @dev Checks if an account is a governor with cancellation privileges.
     *
     * To have governor cancellation rights, an account must:
     * 1. Have the CANCELLER_ROLE in this contract
     * 2. Have the GOVERNOR_ROLE in the access manager
     *
     * Governors with cancel rights can cancel any proposal except guardian expiry proposals,
     * which have special handling.
     *
     * @param account The address to check
     * @return bool True if the account is a governor with cancel rights
     */
    function _isGovernorWithCancelRole(
        address account
    ) internal view returns (bool) {
        return
            hasRole(CANCELLER_ROLE, account) &&
            accessManager.hasRole(accessManager.GOVERNOR_ROLE(), account);
    }

    /**
     * @dev Checks if an account is an active guardian with cancellation privileges.
     *
     * To have guardian cancellation rights, an account must:
     * 1. Have the CANCELLER_ROLE in this contract
     * 2. Be an active guardian in the access manager
     *
     * Active guardians with cancel rights can cancel any proposal EXCEPT guardian
     * expiry proposals, which can only be cancelled by governors.
     *
     * @param account The address to check
     * @return bool True if the account is an active guardian with cancel rights
     */
    function _isActiveGuardianWithCancelRole(
        address account
    ) internal view returns (bool) {
        return
            hasRole(CANCELLER_ROLE, account) &&
            accessManager.isActiveGuardian(account);
    }

    // Override schedule to track guardian expiry operations
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);

        // Check if this is a guardian expiry operation before scheduling
        if (
            bytes4(data) ==
            IProtocolAccessManager.setGuardianExpiration.selector
        ) {
            _guardianExpiryOperations[id] = true;
        }

        super.schedule(target, value, data, predecessor, salt, delay);
    }

    // Override scheduleBatch to track guardian expiry operations
    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override onlyRole(PROPOSER_ROLE) {
        bytes32 id = hashOperationBatch(
            targets,
            values,
            payloads,
            predecessor,
            salt
        );

        for (uint256 i = 0; i < payloads.length; i++) {
            if (
                bytes4(payloads[i]) ==
                IProtocolAccessManager.setGuardianExpiration.selector
            ) {
                _guardianExpiryOperations[id] = true;
            }
        }

        super.scheduleBatch(
            targets,
            values,
            payloads,
            predecessor,
            salt,
            delay
        );
    }
}
