// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title RwaTimelock
 *
 * @notice Thin, behaviour-preserving wrapper over OpenZeppelin's battle-tested
 *         {TimelockController}, used to gate governance of the institutional RWA stack.
 *
 *         Two instances are deployed per institution (same code, different config):
 *         - the "Governor timelock": granted `GOVERNOR_ROLE` on the institution's
 *           `ProtocolAccessManager` and made its *sole* governor. Every governor-gated action
 *           (HarborCommand enlist/decommission, RoundsVault emergency controls, role grants, ...)
 *           flows through it.
 *         - the "Curator timelock": granted the per-fleet `CURATOR_ROLE` on each FleetCommander.
 *           Curation actions flow through it.
 *
 * @dev Delay semantics — the timelock is ALWAYS present; its `minDelay` decides the cadence:
 *      - `minDelay == 0`: an operation can be scheduled and executed in the same block, i.e. it
 *        executes immediately. The operational flow (schedule -> execute) is therefore identical
 *        whether or not a real delay is enforced — callers never need a separate "no timelock"
 *        code path.
 *      - `minDelay > 0`: the operation can only be executed once `minDelay` seconds have elapsed
 *        since it was scheduled, enforcing a mandatory review window for that role's actions.
 *
 *      Per institution the two instances are configured independently: e.g. a non-zero governor
 *      delay with a zero curator delay enforces a waiting period on governance but lets curation
 *      execute immediately, and vice-versa.
 *
 * @dev Executors are expected to be set to the zero address (open execution) so that, once an
 *      operation is ready, anyone may execute it; proposers are the institution's governor set.
 *      No logic is overridden here — the named wrapper exists for deployment / subgraph clarity
 *      and as a future extension point.
 */
contract RwaTimelock is TimelockController {
    /**
     * @param minDelay Minimum delay (in seconds) before a scheduled operation can execute. Pass 0
     *                 for immediate execution.
     * @param proposers Accounts granted `PROPOSER_ROLE` (and `CANCELLER_ROLE`) — typically the
     *                  institution's governor addresses (and the deployer during bootstrap).
     * @param executors Accounts granted `EXECUTOR_ROLE`. Pass `[address(0)]` for open execution.
     * @param admin Optional admin granted `DEFAULT_ADMIN_ROLE`. Pass `address(0)` for a fully
     *              self-administered timelock (recommended) so role changes must go through the
     *              timelock itself.
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
