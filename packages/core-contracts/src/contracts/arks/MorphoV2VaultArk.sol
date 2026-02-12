// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;
import {ArkParams} from "../../types/ArkTypes.sol";
import {ERC4626Ark} from "./ERC4626Ark.sol";

/**
 * @title MorphoV2VaultArk
 * @notice Ark contract for managing token supply and yield generation through MetaMorpho vaults.
 * @dev Implements strategy for depositing tokens, withdrawing tokens, and claiming rewards from MetaMorpho vaults.
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
     * @dev ** best effort approach **
     * the morpho v2 vault returns 0 for maxWithdraw and other max methods
     * so we need to use previewRedeem to get the actual amount that can be withdrawn
     * according to EIP4626 previewRedeem  `MUST NOT revert due to vault specific user/global limits.
     * MAY revert due to other conditions that would also cause redeem to revert.`
     * so we need to catch the revert and return 0.
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 shares = vault.balanceOf(address(this));
        if (shares > 0) {
            try vault.previewRedeem(shares) returns (uint256 amount) {
                withdrawableAssets = amount;
            } catch {
                withdrawableAssets = 0;
            }
        }
    }
}
