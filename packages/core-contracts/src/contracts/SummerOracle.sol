// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerOracle, IOracle, IPriceOracle} from "../interfaces/ISummerOracle.sol";
import {IPriceOracle} from "../interfaces/euler/IPriceOracle.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title SummerOracle
/// @notice Oracle adapter that quotes between FleetCommander ERC4626 shares and its underlying asset.
/// @dev Implements Morpho's IOracle (single price scaled by 1e36) and Euler's / ERC-7726 IPriceOracle (quotes for fleet/quote).
contract SummerOracle is ISummerOracle {
    using Math for uint256;

    IERC4626 public immutable fleet;
    address public immutable asset; // underlying asset of the fleet
    string public oracleName;
    uint8 fleetDecimals;
    uint8 assetDecimals;

    constructor(address _fleet) {
        if (address(_fleet) == address(0)) {
            revert InvalidFleet();
        }
        if (IERC4626(_fleet).asset() == address(0)) {
            revert InvalidAsset();
        }
        fleet = IERC4626(_fleet);
        asset = IERC4626(_fleet).asset();
        oracleName = IERC4626(_fleet).name();
        fleetDecimals = IERC20Metadata(address(fleet)).decimals();
        assetDecimals = IERC20Metadata(asset).decimals();
        if (fleetDecimals != assetDecimals) {
            revert InvalidDecimals();
        }
    }

    /// @inheritdoc IPriceOracle
    function name() external view returns (string memory) {
        return oracleName;
    }

    /// @inheritdoc IOracle
    function price() external view returns (uint256) {
        uint256 oneShareUnit = 10 ** uint256(fleetDecimals);
        uint256 oneAssetUnit = 10 ** uint256(assetDecimals);
        uint256 assetsForOneShareUnit = fleet.convertToAssets(oneShareUnit);
        return assetsForOneShareUnit.mulDiv(1e36, oneAssetUnit);
    }

    /// @inheritdoc ISummerOracle
    function getRate() external view returns (uint256 assetsForOneShareUnit) {
        uint256 oneShareUnit = 10 ** uint256(fleetDecimals);
        assetsForOneShareUnit = fleet.convertToAssets(oneShareUnit);
    }
    /// @inheritdoc IPriceOracle
    function getQuote(
        uint256 _inAmount,
        address _base,
        address _quote
    ) external view returns (uint256 outAmount) {
        if (_inAmount == 0 || _base == _quote) {
            return _inAmount;
        }
        if (_base == address(fleet) && _quote == asset) {
            return fleet.convertToAssets(_inAmount);
        }
        if (_base == asset && _quote == address(fleet)) {
            return fleet.convertToShares(_inAmount);
        }

        revert UnsupportedPair(_base, _quote);
    }

    /// @inheritdoc IPriceOracle
    function getQuotes(
        uint256 _inAmount,
        address _base,
        address _quote
    ) external view returns (uint256 bidOutAmount, uint256 askOutAmount) {
        uint256 out = this.getQuote(_inAmount, _base, _quote);
        return (out, out);
    }
}
