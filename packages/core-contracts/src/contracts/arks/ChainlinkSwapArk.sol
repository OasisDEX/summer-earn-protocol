// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.26;

// import {BaseSwapArk, ArkParams} from "./BaseSwapArk.sol";

// contract ChainlinkSwapArk is BaseSwapArk {
//     AggregatorV3Interface public priceFeed;

//     constructor(ArkParams memory _params, address _arkToken, address _priceFeed) BaseSwapArk(_params, _arkToken) {
//         priceFeed = AggregatorV3Interface(_priceFeed);
//     }

//     function getExchangeRate() public view override returns (uint256) {
//         (, int256 price, , , ) = priceFeed.latestRoundData();
//         require(price > 0, "Invalid price");
//         return uint256(price);
//     }
// }