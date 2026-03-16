// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface ISyrupPool is IERC4626 {
    /**
     *  @dev    Requests a redemption of shares from the pool.
     *  @param  shares_       The amount of shares to redeem.
     *  @param  owner_        The owner of the shares.
     *  @return escrowShares_ The amount of shares sent to escrow.
     */
    function requestRedeem(
        uint256 shares_,
        address owner_
    ) external returns (uint256 escrowShares_);

    /**
     *  @dev    The address of the account that is allowed to update the vesting schedule.
     *  @return manager_ The address of the pool manager.
     */
    function manager() external view returns (address manager_);

    /**
     *  @dev    Returns the amount of exit assets for the input amount.
     *  @param  shares_ The amount of shares to convert to assets.
     *  @return assets_ Amount of assets able to be exited.
     */
    function convertToExitAssets(
        uint256 shares_
    ) external view returns (uint256 assets_);

    /**
     *  @dev    Returns the amount of exit shares for the input amount.
     *  @param  assets_ The amount of assets to convert to shares.
     *  @return shares_ Amount of shares able to be exited.
     */
    function convertToExitShares(
        uint256 assets_
    ) external view returns (uint256 shares_);

    /**
     *  @dev    Removes shares from the withdrawal mechanism, can only be called after the beginning of the withdrawal
     * window has passed.
     *  @param  shares_         The amount of shares to redeem.
     *  @param  owner_          The owner of the shares.
     *  @return sharesReturned_ The amount of shares withdrawn.
     */
    function removeShares(
        uint256 shares_,
        address owner_
    ) external returns (uint256 sharesReturned_);
}
