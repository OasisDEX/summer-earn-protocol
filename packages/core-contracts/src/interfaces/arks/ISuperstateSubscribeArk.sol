// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IArk} from "../IArk.sol";
import {IArkWithWithdrawalRequest} from "../IArkWithWithdrawalRequest.sol";
import {ISuperstateArkErrors} from "../../errors/arks/ISuperstateArkErrors.sol";
import {ISuperstateArkEvents} from "../../events/arks/ISuperstateArkEvents.sol";
import {ISuperstateSubscribeArkErrors} from "../../errors/arks/ISuperstateSubscribeArkErrors.sol";

/// @title ISuperstateSubscribeArk
/// @notice Aggregates the withdrawal-request Ark interface with Superstate subscribe-Ark events and errors
interface ISuperstateSubscribeArk is
    IArkWithWithdrawalRequest,
    ISuperstateArkErrors,
    ISuperstateArkEvents,
    ISuperstateSubscribeArkErrors
{}
