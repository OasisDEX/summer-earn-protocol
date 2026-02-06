// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IRToken} from "../../interfaces/reserve-protocol/IRToken.sol";
import {IBasketHandler} from "../../interfaces/reserve-protocol/IBasketHandler.sol";
import "../Ark.sol";

/**
 * @title ReserveProtocolArk
 * @notice Ark contract for managing token supply and yield generation through Reserve Protocol.
 * @dev Implements strategy for supplying tokens, withdrawing tokens, and claiming rewards on Reserve Protocol.

 */
contract ReserveProtocolArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Reserve Protocol rToken address
    IRToken public immutable rToken;
    /// @notice The Reserve Protocol BasketHandler address
    IBasketHandler public immutable basketHandler;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for ReserveProtocolArk
     * @param _rToken Address of the Reserve Protocol pool
     * @param _basketHandler Address of the Reserve Protocol BasketHandler
     * @param _rewardsController Address of the Reserve Protocol rewards controller
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _rToken,
        address _basketHandler,
        ArkParams memory _params
    ) Ark(_params) {
        rToken = IRToken(_rToken);
        basketHandler = IBasketHandler(_basketHandler);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256 assets) {
        assets = IERC20(rToken).balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev ReserveProtocolArk is withdrawable if the asset is active, not frozen, and not paused
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 configData = rToken
            .getReserveData(address(config.asset))
            .configuration
            .data;
        // We dont check if asset is frozen as
        // Withdrawals and repayments on the assets frozen are completely active, together with liquidations.
        // Only “additive” actions like supplying and borrowing them are halted.
        if (!(_isActive(configData) && !_isPaused(configData))) {
            return 0;
        }
        uint256 _totalAssets = totalAssets();
        if (_totalAssets == 0) {
            return 0;
        }
        uint256 assetsInAToken = config.asset.balanceOf(rToken);
        withdrawableAssets = assetsInAToken < _totalAssets
            ? assetsInAToken
            : _totalAssets;
    }

    /**
     * @notice Harvests rewards from the Aave V3 pool
     * @param /// data Additional data for the harvest operation
     * @return rewardTokens Array of reward tokens
     * @return rewardAmounts Array of reward amounts
     *
     * @dev There are no rewards attached to the RToken, they are accessed through the RSR token which can
     *      only be purchased on exchanges.
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        // no-op
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    /**
     * @notice Boards the Ark by supplying the specified amount of tokens to the Aave V3 pool
     * @param amount Amount of tokens to supply
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(rToken), amount);
        rToken.issue(amount);
    }

    /**
     * @notice Disembarks the Ark by withdrawing the specified amount of tokens from the Aave V3 pool
     * @param amount Amount of tokens to withdraw
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        rToken.redeem(amount);
    }

    /**
     * @notice Validates the board data
     * @dev Aave V3 Ark does not require any validation for board data
     */
    function _validateBoardData(bytes calldata ta) internal override {
        // no-op
    }

    /**
     * @notice Validates the disembark data
     * @dev Aave V3 Ark does not require any validation for board or disembark data
     */
    function _validateDisembarkData(bytes calldata) internal override {
        // no-op
    }

    /// HELPERS

    /**
     * @notice Checks if the reserve is active based on the configuration data
     *
     * @param configData The configuration data of the reserve
     *
     * @return True if the reserve is active, false otherwise
     *
     * @dev A pool can be active or not in the normal lifecycle of the protocol
     */
    function _isActive(uint256 configData) internal pure returns (bool) {
        return configData & ~Constants.ACTIVE_MASK != 0;
    }

    /**
     * @notice Checks if the reserve is paused based on the configuration data
     *
     * @param configData The configuration data of the reserve
     *
     * @return True if the reserve is paused, false otherwise
     *
     * @dev A pool can be paused by the Aave governance to stop all actions on the reserve in case of an emergency
     */
    function _isPaused(uint256 configData) internal pure returns (bool) {
        return configData & ~Constants.PAUSED_MASK != 0;
    }
}
