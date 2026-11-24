// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../IArk.sol";
import {ICapArkErrors} from "../../errors/arks/ICapArkErrors.sol";
import {ICapArkEvents} from "../../events/arks/ICapArkEvents.sol";

/**
 * @title ICapArk
 * @notice Interface for the CapArk contract.
 */
interface ICapArk is IArk, ICapArkEvents, ICapArkErrors {}
