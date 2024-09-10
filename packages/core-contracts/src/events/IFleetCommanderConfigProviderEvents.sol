// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IFleetCommanderConfigProviderEvents {
    /**
     * @notice Emitted when the deposit cap is updated
     * @param newCap The new deposit cap value
     */
    event DepositCapUpdated(uint256 newCap);
    /**
     * @notice Emitted when a new Ark is added
     * @param ark The address of the newly added Ark
     */
    event ArkAdded(address indexed ark);

    /**
     * @notice Emitted when an Ark is removed
     * @param ark The address of the removed Ark
     */
    event ArkRemoved(address indexed ark);
    /**
     *
     * @param newBalance New minimum funds buffer balance
     */
    event FleetCommanderminimumBufferBalanceUpdated(uint256 newBalance);
}
