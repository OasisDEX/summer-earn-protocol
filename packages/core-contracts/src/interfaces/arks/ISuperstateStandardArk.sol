// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IArk} from "../IArk.sol";
import {ISuperstateArkErrors} from "../../errors/arks/ISuperstateArkErrors.sol";
import {ISuperstateArkEvents} from "../../events/arks/ISuperstateArkEvents.sol";
import {ISuperstateStandardArkErrors} from "../../errors/arks/ISuperstateStandardArkErrors.sol";
import {ISuperstateStandardArkEvents} from "../../events/arks/ISuperstateStandardArkEvents.sol";

interface ISuperstateStandardArk is
    IArk,
    ISuperstateArkErrors,
    ISuperstateArkEvents,
    ISuperstateStandardArkErrors,
    ISuperstateStandardArkEvents
{}
