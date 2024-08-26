// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * MIT License
 * ===========
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 */

pragma solidity ^0.8.0;

interface IPendleMarket {
    struct MarketState {
        int256 totalPt;
        int256 totalSy;
        int256 totalLp;
        address treasury;
        /// immutable variables ///
        int256 scalarRoot;
        uint256 expiry;
        /// fee data ///
        uint256 lnFeeRateRoot;
        uint256 reserveFeePercent; // base 100
        /// last trade data ///
        uint256 lastLnImpliedRate;
    }

    function expiry() external view returns (uint256);
    function readTokens()
        external
        view
        returns (address _SY, address _PT, address _YT);
    function isExpired() external view returns (bool);

    function redeemRewards(address user) external returns (uint256[] memory);

    function getRewardTokens() external view returns (address[] memory);

    function readState(
        address router
    ) external view returns (MarketState memory market);
}
