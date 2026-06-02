// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IBenjiToken
 * @notice Minimal interface for the Franklin Templeton iBENJI share token (the `MoneyMarketFund`
 *         ERC20, par $1) held by `BenjiArk`.
 * @dev iBENJI is a standard ERC20 for transfer purposes but gates holders through its
 *      authorization (KYC/whitelist) module: only authorized accounts may receive shares. The
 *      module is not reachable from the token (no public getter), and the Ark reaches iBENJI
 *      exclusively through the `SwapPool`, so only `IERC20Metadata` is required here; the holder
 *      gate surfaces as a revert inside the token if the Ark is not an authorized holder.
 */
interface IBenjiToken is IERC20Metadata {}
