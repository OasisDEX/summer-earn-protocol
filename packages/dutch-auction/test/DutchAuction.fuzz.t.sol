// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/DutchAuctionLibrary.sol";
import {DutchAuctionManager} from "../src/DutchAuctionManger.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DutchAuctionFuzzTest is Test {
    //   address constant address(DutchAuctionLibrary) = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    DutchAuctionLibrary.Auction auction;
    DutchAuctionManager public auctionManager;
    ERC20Mock auctionToken;
    ERC20Mock paymentToken;

    function setUp() public {
        auctionToken = new ERC20Mock();
        paymentToken = new ERC20Mock();
        auctionManager = new DutchAuctionManager();
        auctionToken.mint(address(auctionManager), 1000000e18);
        paymentToken.mint(address(this), 1000000e18);
    }

    function testFuzz_GetCurrentPrice_Linear(
        uint256 _duration,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _totalTokens,
        uint256 _elapsedTime,
        uint256 _kickerRewardPercentage
    ) public {
        // Bound inputs to reasonable ranges
        _duration = bound(_duration, 1 hours, 30 days);
        _startPrice = bound(_startPrice, 1e18, 1000e18);
        _endPrice = bound(_endPrice, 1, _startPrice - 1);
        _totalTokens = bound(_totalTokens, 1e18, 1000000e18);
        _elapsedTime = bound(_elapsedTime, 0, _duration);
        _kickerRewardPercentage = bound(_kickerRewardPercentage, 0, 99);

        auctionToken.approve(address(auctionManager), _totalTokens);
        // Create auction
        auctionManager.createAuction(
            IERC20(address(auctionToken)),
            IERC20(address(paymentToken)),
            _duration,
            _startPrice,
            _endPrice,
            _totalTokens,
            _kickerRewardPercentage,
            address(this),
            true // Linear decay
        );

        // Warp to some time within the auction duration
        vm.warp(block.timestamp + _elapsedTime);

        uint256 currentPrice = auctionManager.getCurrentPrice(0);

        // Calculate expected price
        uint256 expectedPrice = _startPrice -
            (((_startPrice - _endPrice) * _elapsedTime) / _duration);

        // Assert that the current price is within 1 wei of the expected price (to account for rounding)
        assertApproxEqAbs(currentPrice, expectedPrice, 1);
    }

    function testFuzz_GetCurrentPrice_Exponential(
        uint256 _duration,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _totalTokens,
        uint256 _elapsedTime,
        uint256 _kickerRewardPercentage
    ) public {
        // Bound inputs to reasonable ranges
        _duration = bound(_duration, 1 hours, 30 days);
        _startPrice = bound(_startPrice, 1e18, 1000e18);
        _endPrice = bound(_endPrice, 1, _startPrice - 1);
        _totalTokens = bound(_totalTokens, 1e18, 1000000e18);
        _elapsedTime = bound(_elapsedTime, 0, _duration);
        _kickerRewardPercentage = bound(_kickerRewardPercentage, 0, 99);

        auctionToken.approve(address(auctionManager), _totalTokens);
        // Create auction
        auctionManager.createAuction(
            IERC20(address(auctionToken)),
            IERC20(address(paymentToken)),
            _duration,
            _startPrice,
            _endPrice,
            _totalTokens,
            _kickerRewardPercentage,
            address(this),
            false // Exponential decay
        );

        // Warp to some time within the auction duration
        vm.warp(block.timestamp + _elapsedTime);

        uint256 currentPrice = auctionManager.getCurrentPrice(0);

        // Calculate expected price
        uint256 expectedPrice = _endPrice +
            (((_startPrice - _endPrice) * (_duration - _elapsedTime) ** 2) /
                _duration ** 2);

        // Assert that the current price is within 1 wei of the expected price (to account for rounding)
        assertApproxEqAbs(currentPrice, expectedPrice, 1);
    }

    function testFuzz_GetCurrentPrice_Boundaries(
        uint256 _duration,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _totalTokens
    ) public {
        // Bound inputs to reasonable ranges
        _duration = bound(_duration, 1 hours, 30 days);
        _startPrice = bound(_startPrice, 1e18, 1000e18);
        _endPrice = bound(_endPrice, 1, _startPrice - 1);
        _totalTokens = bound(_totalTokens, 1e18, 1000000e18);

        auctionToken.approve(address(auctionManager), _totalTokens);
        // Create auction
        auctionManager.createAuction(
            IERC20(address(auctionToken)),
            IERC20(address(paymentToken)),
            _duration,
            _startPrice,
            _endPrice,
            _totalTokens,
            5, // 5% kicker reward
            address(this),
            true // Linear decay (works for both linear and exponential)
        );

        // Test at start time
        uint256 currentPrice = auctionManager.getCurrentPrice(0);
        assertEq(
            currentPrice,
            _startPrice,
            "Price should be start price at auction start"
        );

        // Test at end time
        vm.warp(block.timestamp + _duration);
        currentPrice = auctionManager.getCurrentPrice(0);
        assertEq(
            currentPrice,
            _endPrice,
            "Price should be end price at auction end"
        );

        // Test after end time
        vm.warp(block.timestamp + 1 days);
        currentPrice = auctionManager.getCurrentPrice(0);
        assertEq(
            currentPrice,
            _endPrice,
            "Price should remain at end price after auction end"
        );
    }
}
