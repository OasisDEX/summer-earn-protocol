// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IBaseSwapArkErrors} from "../../errors/arks/IBaseSwapArkErrors.sol";
import {IBaseSwapArkEvents} from "../../events/arks/IBaseSwapArkEvents.sol";

interface IBaseSwapArk is IBaseSwapArkErrors, IBaseSwapArkEvents {}
