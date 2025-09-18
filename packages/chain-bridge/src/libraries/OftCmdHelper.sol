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
}
