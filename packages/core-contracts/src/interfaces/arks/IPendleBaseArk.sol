// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPendleBaseArkErrors} from "../../errors/arks/IPendleBaseArkErrors.sol";
import {IPendleBaseArkEvents} from "../../events/arks/IPendleBaseArkEvents.sol";

interface IPendleBaseArk is IPendleBaseArkEvents, IPendleBaseArkErrors {}
