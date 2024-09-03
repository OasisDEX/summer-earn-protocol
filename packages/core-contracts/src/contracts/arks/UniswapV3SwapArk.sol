// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.26;

// import {BaseSwapArk, ArkParams} from "./BaseSwapArk.sol";

// contract UniswapV3SwapArk is BaseSwapArk {
//     IUniswapV3Pool public pool;
//     uint32 public twapInterval;

//     constructor(
//         ArkParams memory _params,
//         address _arkToken,
//         address _pool,
//         uint32 _twapInterval
//     ) BaseSwapArk(_params, _arkToken) {
//         pool = IUniswapV3Pool(_pool);
//         twapInterval = _twapInterval;
//     }

//     function getExchangeRate() public view override returns (uint256) {
//         (int24 arithmeticMeanTick, ) = OracleLibrary.consult(
//             address(pool),
//             twapInterval
//         );
//         return TickMath.getSqrtRatioAtTick(arithmeticMeanTick) ** 2;
//     }
// }
