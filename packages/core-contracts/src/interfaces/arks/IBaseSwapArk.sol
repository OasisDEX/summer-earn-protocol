// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IBaseSwapArkErrors} from "../../errors/arks/IBaseSwapArkErrors.sol";
import {IBaseSwapArkEvents} from "../../events/arks/IBaseSwapArkEvents.sol";

interface IBaseSwapArk is IBaseSwapArkErrors, IBaseSwapArkEvents {}
