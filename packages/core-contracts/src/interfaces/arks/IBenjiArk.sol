// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBenjiArkErrors} from "../../errors/arks/IBenjiArkErrors.sol";
import {IBenjiArkEvents} from "../../events/arks/IBenjiArkEvents.sol";
import {IArkSwapProvider} from "../IArkSwapProvider.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title IBenjiArk
 * @notice Interface for `BenjiArk` — the Franklin Templeton iBENJI Ark.
 * @dev Extends `IArkSwapProvider` (which extends `IArk`) because the Ark's escape hatch is the
 *      curator-whitelisted router swap; the SwapPool entry/exit itself is synchronous, so there is
 *      no `IArkWithWithdrawalRequest` surface.
 */
interface IBenjiArk is IArkSwapProvider, IBenjiArkErrors, IBenjiArkEvents {
    /**
     * @notice Converts an iBENJI share amount to the equivalent base-asset amount at 1:1 par.
     * @param shares Amount in `shareDecimals`
     * @return assets Equivalent amount in `assetDecimals`
     */
    function sharesToAssets(uint256 shares) external view returns (uint256);

    /**
     * @notice Whether this Ark is an authorized trader for the asset/iBENJI pair on the given
     *         SwapPool and may therefore swap through it. Trader authorization is granted
     *         off-chain by Franklin Templeton per pool.
     * @param swapPool The SwapPool to check
     */
    function isArkOnboarded(address swapPool) external view returns (bool);

    /**
     * @notice Whether the given SwapPool is approved by the curator for board/disembark.
     * @param swapPool The SwapPool to check
     */
    function whitelistedSwapPools(
        address swapPool
    ) external view returns (bool);

    /**
     * @notice Adds or removes a SwapPool from the curator whitelist. The keeper selects one of the
     *         whitelisted pools per rebalance via `boardData`/`disembarkData`
     *         (`abi.encode(address pool)`).
     * @param swapPool The SwapPool address
     * @param isWhitelisted The new whitelist status
     */
    function whitelistSwapPool(address swapPool, bool isWhitelisted) external;

    /**
     * @notice Sets the board (deposit) slippage tolerance.
     * @param newDepositSlippage The new deposit slippage
     */
    function setDepositSlippage(Percentage newDepositSlippage) external;
}
