// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @notice Stargate implementation type.
enum StargateType {
    Pool,
    OFT
}

/// @notice Ticket data for bus ride.
struct Ticket {
    uint72 ticketId;
    bytes passengerBytes;
}

/// @title Interface for Stargate.
/// @notice Defines an API for sending tokens to destination chains.
interface IStargate {
    /// @notice Returns the Stargate implementation type.
    function stargateType() external pure returns (StargateType);
}
