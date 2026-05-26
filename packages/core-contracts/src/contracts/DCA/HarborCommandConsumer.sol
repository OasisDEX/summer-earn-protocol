// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHarborCommand} from "../../interfaces/IHarborCommand.sol";

/**
 * @title HarborCommandConsumer
 * @notice Abstract base contract for contracts that need to verify whether an
 *         address is an active FleetCommander registered in HarborCommand.
 *
 * @dev Exposes the `onlyActiveFleetCommander` modifier. Pass a human-readable
 *      label (e.g. "source", "target") so the `InactiveFleetCommander` revert
 *      identifies which vault failed the check.
 */
abstract contract HarborCommandConsumer {
    /// @notice The HarborCommand registry used to verify active FleetCommanders.
    IHarborCommand public immutable HARBOR_COMMAND;

    /// @notice Reverts when the provided HarborCommand address is the zero address.
    error InvalidHarborCommandAddress();

    /**
     * @notice Reverts when `vault` is not registered as an active FleetCommander.
     * @param vault  The vault address that failed the check.
     * @param label  Human-readable identifier for the vault role (e.g. "source", "target").
     */
    error InactiveFleetCommander(address vault, string label);

    /**
     * @param _harborCommand Address of the deployed HarborCommand registry. Must be non-zero.
     */
    constructor(address _harborCommand) {
        if (_harborCommand == address(0)) revert InvalidHarborCommandAddress();
        HARBOR_COMMAND = IHarborCommand(_harborCommand);
    }

    /**
     * @dev Reverts with `InactiveFleetCommander` when `vault` is not an active
     *      FleetCommander according to the HarborCommand registry.
     * @param vault  The vault address to check.
     * @param label  Human-readable label for the vault role ("source", "target", …).
     */
    modifier onlyActiveFleetCommander(address vault, string memory label) {
        if (!HARBOR_COMMAND.activeFleetCommanders(vault)) {
            revert InactiveFleetCommander(vault, label);
        }
        _;
    }
}
