// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IMorpho, Id, Market, MarketParams, Position} from "morpho-blue/interfaces/IMorpho.sol";

import {MarketParamsLib} from "morpho-blue/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "morpho-blue/libraries/SharesMathLib.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {MorphoBalancesLib} from "morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoLib} from "morpho-blue/libraries/periphery/MorphoLib.sol";

error InvalidMorphoAddress();
error InvalidMarketId();

/**
 * @title MorphoArk
 * @notice This contract manages a Morpho token strategy within the Ark system
 */
contract MorphoArk is Ark {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Morpho Vault address
    IMorpho public immutable MORPHO;
    /// @notice The market ID
    Id public marketId;
    /// @notice The market parameters
    MarketParams public marketParams;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for MorphoArk
     * @param _morpho The Morpho Vault address
     * @param _marketId The market ID
     */

    constructor(
        address _morpho,
        Id _marketId,
        ArkParams memory _arkParams
    ) Ark(_arkParams) {
        if (_morpho == address(0)) {
            revert InvalidMorphoAddress();
        }
        if (Id.unwrap(_marketId) == 0) {
            revert InvalidMarketId();
        }
        MORPHO = IMorpho(_morpho);
        marketId = _marketId;
        marketParams = MORPHO.idToMarketParams(_marketId);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256) {
        Position memory position = MORPHO.position(marketId, address(this));
        Market memory market = MORPHO.market(marketId);

        return
            position.supplyShares.toAssetsDown(
                market.totalSupplyAssets,
                market.totalSupplyShares
            );
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Boards tokens into the Morpho Vault
     * @param amount The amount of tokens to board
     */
    function _board(uint256 amount, bytes calldata) internal override {
        MORPHO.accrueInterest(marketParams);
        config.token.approve(address(MORPHO), amount);
        MORPHO.supply(marketParams, amount, 0, address(this), hex"");
    }

    /**
     * @notice Disembarks tokens from the Morpho Vault
     * @param amount The amount of tokens to disembark
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        MORPHO.accrueInterest(marketParams);
        MORPHO.withdraw(marketParams, amount, 0, address(this), address(this));
    }

    /**
     * @notice No-op for harvest function
     * @dev MorphoArk does not generate any rewards, so this function is not implemented
     * todo Implement rewards collection for MorphoArk if required
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {}

    /**
     * @notice No-op for validateBoardData function
     * @dev MorphoArk does not require any validation for board data
     */
    function _validateBoardData(bytes calldata data) internal override {}

    /**
     * @notice No-op for validateDisembarkData function
     * @dev MorphoArk does not require any validation for disembark data
     */
    function _validateDisembarkData(bytes calldata data) internal override {}
}
