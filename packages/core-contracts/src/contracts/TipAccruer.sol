// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ITipAccruer} from "../interfaces/ITipAccruer.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../errors/TipAccruerErrors.sol";
import "../interfaces/IConfigurationManager.sol";

/// @title TipAccruer
/// @notice Contract implementing tip accrual functionality
/// @dev This contract is designed to be instantiated by the FleetCommander
contract TipAccruer is ITipAccruer {
    /// @notice The current tip rate in basis points
    /// @dev 100 basis points = 1%
    uint256 public tipRate;

    /// @notice The timestamp of the last tip accrual
    uint256 public lastTipTimestamp;

    /// @notice The address where accrued tips are sent
    address public tipJar;

    /// @notice The address of the FleetCommander contract
    address public fleetCommander;

    /// @dev Constant representing 100% in basis points
    uint256 private constant BASIS_POINTS = 10000;

    /// @dev Constant representing the number of seconds in a year
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /// @notice Emitted when the tip rate is updated
    /// @param newTipRate The new tip rate value
    event TipRateUpdated(uint256 newTipRate);

    /// @notice Emitted when tips are accrued
    /// @param tipAmount The amount of tips accrued
    event TipAccrued(uint256 tipAmount);

    /// @notice Emitted when the tip jar address is updated
    /// @param newTipJar The new tip jar address
    event TipJarUpdated(address newTipJar);

    /// @notice Initializes the TipAccruer contract
    /// @param configurationManager The address of the ConfigurationManager contract
    /// @param _fleetCommander The address of the FleetCommander contract
    constructor(address configurationManager, address _fleetCommander_) {
        if (_fleetCommander_ != address(0)) {
            revert InvalidFleetCommanderAddress();
        }
        IConfigurationManager manager = IConfigurationManager(
            configurationManager
        );
        tipRate = manager.tipRate();
        tipJar = manager.tipJar();
        fleetCommander = _fleetCommander_;
        lastTipTimestamp = block.timestamp;
    }

    /// @notice Sets a new tip rate
    /// @dev Only callable by the FleetCommander. Accrues tips before changing the rate.
    /// @param _newTipRate The new tip rate to set (in basis points)
    function setTipRate(uint256 _newTipRate) external {
        require(
            msg.sender == fleetCommander,
            "Only FleetCommander can set tip rate"
        );
        require(_newTipRate <= BASIS_POINTS, "TipRate cannot exceed 100%");
        accrueTip(); // Accrue tips before changing the rate
        tipRate = _newTipRate;
        emit TipRateUpdated(_newTipRate);
    }

    /// @notice Sets a new tip jar address
    /// @dev Only callable by the FleetCommander
    /// @param _newTipJar The new address to set as the tip jar
    function setTipJar(address _newTipJar) external {
        require(
            msg.sender == fleetCommander,
            "Only FleetCommander can set tip jar"
        );
        require(_newTipJar != address(0), "Invalid TipJar address");
        tipJar = _newTipJar;
        emit TipJarUpdated(_newTipJar);
    }

    /// @notice Accrues tips based on the current tip rate and time elapsed
    /// @dev Only callable by the FleetCommander
    /// @return tipAmount The amount of tips accrued
    function accrueTip() public returns (uint256 tipAmount) {
        require(
            msg.sender == fleetCommander,
            "Only FleetCommander can accrue tip"
        );
        uint256 timeElapsed = block.timestamp - lastTipTimestamp;
        if (timeElapsed == 0) return 0;

        uint256 totalAssets = IERC4626(fleetCommander).totalAssets();
        tipAmount = _calculateTip(totalAssets, timeElapsed);

        if (tipAmount > 0) {
            emit TipAccrued(tipAmount);
        }

        lastTipTimestamp = block.timestamp;
    }

    /// @notice Calculates the tip amount based on total assets and time elapsed
    /// @param _totalAssets The total assets to calculate tips on
    /// @param _timeElapsed The time elapsed since the last tip accrual
    /// @return The calculated tip amount
    function _calculateTip(
        uint256 _totalAssets,
        uint256 _timeElapsed
    ) internal view returns (uint256) {
        return
            (_totalAssets * tipRate * _timeElapsed) /
            BASIS_POINTS /
            SECONDS_PER_YEAR;
    }

    /// @notice Estimates the amount of tips accrued since the last tip accrual
    /// @return The estimated amount of accrued tips
    function estimateAccruedTip() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastTipTimestamp;
        uint256 totalAssets = IERC4626(fleetCommander).totalAssets();
        return _calculateTip(totalAssets, timeElapsed);
    }
}
