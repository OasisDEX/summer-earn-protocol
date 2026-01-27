// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./ERC4626Ark.sol";

/**
 * @title MorphoVaultV2Ark
 * @notice Ark contract for managing token supply and yield generation through Morpho V2 vaults.
 * @dev Extends ERC4626Ark to use vault balance for withdrawable assets calculation.
 */
contract MorphoVaultV2Ark is ERC4626Ark {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to set up the MorphoVaultV2Ark
     * @param _vault Address of the Morpho V2 vault
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
     * @dev Overrides ERC4626Ark to check vault balance instead of maxWithdraw
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 shares = vault.balanceOf(address(this));
        // Get the idle assets available in the vault
        uint256 idleAssets = config.asset.balanceOf(address(vault));
        if (shares > 0 && idleAssets > 0) {
            // Get the total assets owned by the Ark
            uint256 assetsOwned = vault.convertToAssets(shares);

            // Return the minimum of assets owned and available idle assets
            withdrawableAssets = idleAssets < assetsOwned
                ? idleAssets
                : assetsOwned;
        }
    }
}
