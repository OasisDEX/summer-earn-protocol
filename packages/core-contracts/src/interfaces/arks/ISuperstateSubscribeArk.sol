// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IArk} from "../IArk.sol";
import {IArkWithWithdrawalRequest} from "../IArkWithWithdrawalRequest.sol";
import {ISuperstateArkErrors} from "../../errors/arks/ISuperstateArkErrors.sol";
import {ISuperstateArkEvents} from "../../events/arks/ISuperstateArkEvents.sol";
import {ISuperstateSubscribeArkErrors} from "../../errors/arks/ISuperstateSubscribeArkErrors.sol";
import {ISuperstateSubscribeArkEvents} from "../../events/arks/ISuperstateSubscribeArkEvents.sol";

interface ISuperstateSubscribeArk is
    IArkWithWithdrawalRequest,
    ISuperstateArkErrors,
    ISuperstateArkEvents,
    ISuperstateSubscribeArkErrors,
    ISuperstateSubscribeArkEvents
{}
