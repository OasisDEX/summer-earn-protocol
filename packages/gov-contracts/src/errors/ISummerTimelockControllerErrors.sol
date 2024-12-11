// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISummerTimelockControllerErrors {
    /// @notice Error thrown when an unauthorized caller attempts to cancel a guardian expiry proposal
    error TimelockUnauthorizedGuardianExpiryCancel(address caller);
}
