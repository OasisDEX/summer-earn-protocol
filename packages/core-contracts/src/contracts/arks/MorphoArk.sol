// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IMorpho, Id, MarketParams, Market, Position} from "morpho-blue/interfaces/IMorpho.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {IIrm} from "morpho-blue/interfaces/IIrm.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "morpho-blue/libraries/SharesMathLib.sol";
import {MarketParamsLib} from "morpho-blue/libraries/MarketParamsLib.sol";
import {MorphoLib} from "morpho-blue/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

contract MorphoArk is Ark {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant SECONDS_PER_YEAR = 365 days;
    IMorpho public immutable MORPHO;
    Id public marketId;
    MarketParams public marketParams;

    constructor(
        address _morpho,
        bytes32 _id,
        ArkParams memory _arkParams
    ) Ark(_arkParams) {
        MORPHO = IMorpho(_morpho);
        marketId = Id.wrap(_id);
        marketParams = MORPHO.idToMarketParams(marketId);
    }

    function rate() public view override returns (uint256) {
        Market memory market = MORPHO.market(marketId);
        if (market.lastUpdate == 0) {
            return 0;
        }

        IIrm interestRateModel = IIrm(marketParams.irm);
        // Calculate borrow rate
        uint256 borrowRate = interestRateModel.borrowRateView(
            marketParams,
            market
        );
        // Calculate utilization
        uint256 utilization = market.totalSupplyAssets == 0
            ? 0
            : (market.totalBorrowAssets * WAD) / market.totalSupplyAssets;
        // Calculate fee percentage
        uint256 feePercentage = WAD - market.fee;
        // Calculate supply rate
        uint256 supplyRatePerSecond = (borrowRate *
            utilization *
            feePercentage) / (WAD * WAD);
        // Convert to APY
        return (supplyRatePerSecond * SECONDS_PER_YEAR * (RAY / WAD));
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

    function _board(uint256 amount) internal override {
        MORPHO.accrueInterest(marketParams);
        token.approve(address(MORPHO), amount);
        MORPHO.supply(marketParams, amount, 0, address(this), hex"");
    }

    function _disembark(uint256 amount) internal override {
        MORPHO.accrueInterest(marketParams);
        MORPHO.withdraw(marketParams, amount, 0, address(this), address(this));
    }
}
