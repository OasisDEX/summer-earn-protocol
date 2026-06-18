// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IArk} from "../IArk.sol";
import {ISecuritizeArkErrors} from "../../errors/arks/ISecuritizeArkErrors.sol";
import {ISecuritizeArkEvents} from "../../events/arks/ISecuritizeArkEvents.sol";

/**
 * @title ISecuritizeArk
 * @notice Interface for the SecuritizeArk — an off-chain custodial Ark for Securitize DS Protocol
 *         security tokens (e.g. VBILL, ACRED, STAC), valued via a RedStone NAV feed.
 */
interface ISecuritizeArk is IArk, ISecuritizeArkErrors, ISecuritizeArkEvents {}
