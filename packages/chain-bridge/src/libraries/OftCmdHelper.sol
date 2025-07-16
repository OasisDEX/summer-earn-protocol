// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title OftCmdHelper
 * @notice Helper library for creating OFT commands for taxi/bus modes
 * @dev Used by Stargate V2 for transport mode selection
 */
library OftCmdHelper {
    /**
     * @notice Creates taxi mode command (immediate execution)
     * @return Empty bytes for taxi mode
     */
    function taxi() internal pure returns (bytes memory) {
        return "";
    }

    /**
     * @notice Creates bus mode command (batched execution)
     * @return Single byte array for bus mode
     */
    function bus() internal pure returns (bytes memory) {
        return new bytes(1);
    }

    /**
     * @notice Creates drive mode command with passengers
     * @param _passengers The passenger data to include
     * @return The passengers data for drive mode
     */
    function drive(
        bytes memory _passengers
    ) internal pure returns (bytes memory) {
        return _passengers;
    }

    function testSkipper() public {}
}
