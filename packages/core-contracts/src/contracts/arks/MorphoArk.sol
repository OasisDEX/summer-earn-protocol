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

contract MorphoArk is Ark {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    IMorpho public immutable MORPHO;
    Id public marketId;
    MarketParams public marketParams;

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

    function totalAssets() public view override returns (uint256) {
        Position memory position = MORPHO.position(marketId, address(this));
        Market memory market = MORPHO.market(marketId);

        return
            position.supplyShares.toAssetsDown(
                market.totalSupplyAssets,
                market.totalSupplyShares
            );
    }

    function _board(uint256 amount, bytes calldata) internal override {
        MORPHO.accrueInterest(marketParams);
        config.token.approve(address(MORPHO), amount);
        MORPHO.supply(marketParams, amount, 0, address(this), hex"");
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        MORPHO.accrueInterest(marketParams);
        MORPHO.withdraw(marketParams, amount, 0, address(this), address(this));
    }

    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {}
    function _validateBoardData(bytes calldata data) internal override {}
    function _validateDisembarkData(bytes calldata data) internal override {}
}
