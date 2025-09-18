// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {FleetCommanderTestBase} from "../fleets/FleetCommanderTestBase.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {ISummerOracle} from "../../src/interfaces/ISummerOracle.sol";
import {SummerOracleFactory} from "../../src/contracts/SummerOracleFactory.sol";
import {OracleTestHelper} from "../helpers/OracleTestHelper.sol";

contract SummerOracleTest is Test, FleetCommanderTestBase {
    using PercentageUtils for uint256;
    using OracleTestHelper for *;

    function _deployFleet(
        uint8 decimals
    ) internal returns (MockERC20, FleetCommander) {
        MockERC20 underlying = new MockERC20();
        underlying.initialize("U", "U", decimals);

        setupBaseContracts();
        setupFleetCommanderWithBufferArk(
            address(underlying),
            PercentageUtils.fromIntegerPercentage(0)
        );
        vm.label(address(fleetCommander), "FleetCommander");
        vm.label(address(underlying), "Underlying");

        return (underlying, fleetCommander);
    }

    function _deposit(
        address user,
        MockERC20 asset,
        FleetCommander fleet,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        deal(address(asset), user, amount);
        asset.approve(address(fleet), amount);
        fleet.deposit(amount, user);
        vm.stopPrank();
    }

    function _inflateSharePrice(
        MockERC20 asset,
        FleetCommander fleet,
        uint256 amount
    ) internal {
        address buffer = fleet.bufferArk();
        uint bufferBalance = asset.balanceOf(buffer);
        deal(address(asset), buffer, bufferBalance + amount);
    }

    function _runScenario(uint8 decimals) internal {
        (MockERC20 underlying, FleetCommander fleet) = _deployFleet(decimals);
        SummerOracleFactory factory = new SummerOracleFactory(harborCommand);
        ISummerOracle oracle = factory.deploySummerOracle(address(fleet));

        // Deposit 100000 units
        uint256 amount = OracleTestHelper.applyDecimals(100000, decimals);
        uint256 oneShare = OracleTestHelper.applyDecimals(1, decimals);
        _deposit(address(this), underlying, fleet, amount);

        // Sanity: at start, 1 share ~= 1 asset
        uint256 oneShareAssets = fleet.convertToAssets(oneShare);
        assertEq(
            oneShareAssets,
            OracleTestHelper.applyDecimals(1, decimals),
            "One share assets should be equal to 1 token"
        );

        // Inflate share price by adding assets to buffer ark
        _inflateSharePrice(
            underlying,
            fleet,
            OracleTestHelper.applyDecimals(23456, decimals)
        );
        uint256 oneShareAssetsAfterInflation = fleet.convertToAssets(oneShare);
        assertGt(
            oneShareAssetsAfterInflation,
            oneShareAssets,
            "One share assets after inflation should be greater than one share assets"
        );

        // Morpho IOracle: price scaled 1e36 for 1 share in underlying
        uint256 expectedMorpho = OracleTestHelper.expectedMorphoPrice(fleet);
        uint256 morphoPrice = oracle.price();
        assertEq(
            morphoPrice,
            expectedMorpho,
            "Morpho price should be equal to expected morpho price"
        );

        // Euler IPriceOracle: getQuote and getQuotes with no spread
        uint256 inShares = oneShare;
        uint256 outAssets = oracle.getQuote(
            inShares,
            address(fleet),
            fleet.asset()
        );
        assertEq(
            outAssets,
            fleet.convertToAssets(inShares),
            "Out assets should be equal to fleet convert to assets"
        );

        (uint256 bidOut, uint256 askOut) = oracle.getQuotes(
            inShares,
            address(fleet),
            fleet.asset()
        );
        assertEq(bidOut, outAssets, "Bid out should be equal to out assets");
        assertEq(askOut, outAssets, "Ask out should be equal to out assets");

        // Reverse quote: assets -> shares
        uint256 inAssets = OracleTestHelper.applyDecimals(1, decimals);
        uint256 outShares = oracle.getQuote(
            inAssets,
            fleet.asset(),
            address(fleet)
        );
        assertEq(
            outShares,
            fleet.convertToShares(inAssets),
            "Out shares should be equal to fleet convert to shares"
        );

        uint256 rate = oracle.getRate();
        assertEq(
            rate,
            fleet.convertToAssets(oneShare),
            "Rate should be equal to fleet convert to assets"
        );
    }

    function test_SummerOracle_6decimals() public {
        _runScenario(6);
    }

    function test_SummerOracle_8decimals() public {
        _runScenario(8);
    }

    function test_SummerOracle_18decimals() public {
        _runScenario(18);
    }
}
