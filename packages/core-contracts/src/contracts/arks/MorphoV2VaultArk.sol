// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;
import {ArkParams} from "../../types/ArkTypes.sol";
import {ERC4626Ark} from "./ERC4626Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IVaultV2} from "../../interfaces/morpho/IVaultV2.sol";
import {IMorphoVaultV1Adapter} from "../../interfaces/morpho/IMorphoVaultV1Adapter.sol";

/**
 * @title MorphoV2VaultArk
 * @notice Ark contract for managing token supply and yield generation through MetaMorpho vaults.
 * @dev Implements strategy for depositing tokens, withdrawing tokens, and claiming rewards from Morpho VaultV2
 * (MetaMorpho V2).
 *
 * Morpho VaultV2 has a non-conventional ERC-4626 behavior: all `max*()` functions (e.g. `maxWithdraw`) always return
 * `0`. This is an intentional, conservative underestimation to avoid promising a revert-free bound when gates are
 * enabled.
 *
 * Because Fleet logic relies on `withdrawableTotalAssets()` as a planning ceiling (and as the backing for
 * FleetCommander `maxWithdraw`), this Ark overrides `_withdrawableTotalAssets()` to compute a conservative, best-effort
 * bound without using `maxWithdraw`.
 */
contract MorphoV2VaultArk is ERC4626Ark {
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the ERC4626Ark
     * @param _vault Address of the ERC4626-compliant vault
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _vault,
        ArkParams memory _params
    ) ERC4626Ark(_vault, _params) {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev **Best-effort, conservative bound for Morpho VaultV2**.
     *
     * Morpho VaultV2 returns `0` for `maxWithdraw`, so we derive an upper bound as:
     *
     * - `positionAssets`: the Ark's current position value, computed as `previewRedeem(ourShares)`.
     *   If `previewRedeem` reverts, we return `0`.
     * - `liquidAssets`: assets that can be proven to be available for a withdrawal path in the current state:
     *   - `idleAssets`: underlying balance held directly by the vault.
     *   - `adapterLiquidity` (best-effort): if the vault's `liquidityAdapter` is a Morpho `MorphoVaultV1Adapter`, and
     *     the vault is configured to deallocate through it (`liquidityData().length == 0`) and the adapter is active
     *     (`isAdapter(adapter) == true`), then we add `maxWithdraw(adapter)` from the underlying Morpho V1 vault.
     *     all the additional validations logic is implemented to be as close as possible to Morpho V2 vault implementation.
     *
     * Finally, we return `min(positionAssets, liquidAssets)`.
     *
     * This value is intended as a revert-avoiding planning ceiling for Fleet withdrawals; it is conservative by design
     * and may under-report when liquidity exists via other adapters or complex deallocation paths.
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 shares = vault.balanceOf(address(this));
        if (shares == 0) return 0;

        IVaultV2 vaultV2 = IVaultV2(address(vault));

        uint256 positionAssets;
        try vault.previewRedeem(shares) returns (uint256 amount) {
            positionAssets = amount;
        } catch {
            return 0;
        }
        if (positionAssets == 0) return 0;

        uint256 idleAssets = config.asset.balanceOf(address(vault));

        uint256 adapterLiquidity = 0;
        address adapter = vaultV2.liquidityAdapter();
        if (
            adapter != address(0) &&
            vaultV2.liquidityData().length == 0 &&
            vaultV2.isAdapter(adapter)
        ) {
            try IMorphoVaultV1Adapter(adapter).morphoVaultV1() returns (
                address morphoVaultV1
            ) {
                try IERC4626(morphoVaultV1).maxWithdraw(adapter) returns (
                    uint256 maxWithdrawAssets
                ) {
                    adapterLiquidity = maxWithdrawAssets;
                } catch {}
            } catch {}
        }

        uint256 liquidAssets = idleAssets + adapterLiquidity;

        withdrawableAssets = positionAssets < liquidAssets
            ? positionAssets
            : liquidAssets;
    }
}
