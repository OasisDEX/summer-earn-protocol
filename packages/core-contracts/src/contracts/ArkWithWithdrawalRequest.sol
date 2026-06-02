// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

import {IArkSwapProvider} from "../interfaces/IArkSwapProvider.sol";
import {IArkWithWithdrawalRequest} from "../interfaces/IArkWithWithdrawalRequest.sol";
import {ArkConfig, ArkParams} from "../types/ArkTypes.sol";
import {Ark} from "./Ark.sol";
import {ArkSwapProvider} from "./ArkSwapProvider.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

/**
 * @title ArkWithWithdrawalRequest
 * @author SummerFi
 *
 * @notice Abstract base for Arks whose withdrawal path is asynchronous: a `requestWithdrawal` step
 *         initiates the off-chain settlement, and a separate `sweep` (or `claimWithdrawal`) step
 *         brings the underlying asset back to this Ark and forwards it to the FleetCommander's
 *         buffer ark. Inherits the whitelisted-router swap utility (`_swap`, `_applySlippage`,
 *         `whitelistRouter`, `setSlippage`, `_boardToBufferArk`) from `ArkSwapProvider` for exits
 *         that route through a DEX aggregator.
 *
 * @dev Concrete subclasses must still implement the abstract hooks defined on `Ark` (`_board`,
 *      `_disembark`, `_withdrawableTotalAssets`, `_harvest`, `_validateBoardData`,
 *      `_validateDisembarkData`) AND the async-withdrawal hooks declared on
 *      `IArkWithWithdrawalRequest` (`requestWithdrawal`, `claimWithdrawal`, `withdrawUsingSwap`,
 *      `isWithdrawalClaimRequired`, `withdrawalRequestId`, `assetsInWithdrawalQueue`). Slippage on
 *      the internal `_swap` helper is bounded by `MAX_SLIPPAGE` and configured by the curator.
 */
abstract contract ArkWithWithdrawalRequest is
    IArkWithWithdrawalRequest,
    ArkSwapProvider
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Wires the ark with its standard `ArkParams` and the initial swap-slippage tolerance.
     * @param _params Standard ark configuration (asset, commander, deposit caps, etc.).
     * @param _slippage Initial `_swap` slippage in basis points of `SLIPPAGE_BASE`. Must be
     *                  `<= MAX_SLIPPAGE`.
     */
    constructor(
        ArkParams memory _params,
        uint256 _slippage
    ) ArkSwapProvider(_params, _slippage) {}

    // ============================================================
    //                       EXTERNAL FUNCTIONS
    // ============================================================

    /// @inheritdoc IArkWithWithdrawalRequest
    function sweep()
        public
        virtual
        onlyKeeper
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        IERC20 asset = config.asset;
        sweptTokens = new address[](1);
        sweptAmounts = new uint256[](1);

        sweptTokens[0] = address(asset);
        sweptAmounts[0] = asset.balanceOf(address(this));

        address bufferArk = address(
            IFleetCommander(config.commander).bufferArk()
        );
        // @dev First-position arg is `msg.sender` (the keeper) here, NOT the FleetCommander
        //      address that the `Disembarked` event's `commander` parameter nominally represents.
        //      Preserved as-is for subgraph compatibility with the original event signature.
        emit Disembarked(msg.sender, address(asset), sweptAmounts[0]);

        if (sweptAmounts[0] > 0 && address(this) != bufferArk) {
            asset.forceApprove(bufferArk, sweptAmounts[0]);
            IArk(bufferArk).board(sweptAmounts[0], bytes(""));
        }

        emit ArkSwept(sweptTokens, sweptAmounts);
    }
}
