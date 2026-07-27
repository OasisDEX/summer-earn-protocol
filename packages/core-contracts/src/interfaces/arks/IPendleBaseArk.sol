// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IPendleBaseArkErrors} from "../../errors/arks/IPendleBaseArkErrors.sol";
import {IPendleBaseArkEvents} from "../../events/arks/IPendleBaseArkEvents.sol";

/// @title IPendleBaseArk
/// @notice Aggregates the events and errors shared by the Pendle-based Ark implementations
interface IPendleBaseArk is IPendleBaseArkEvents, IPendleBaseArkErrors {}
