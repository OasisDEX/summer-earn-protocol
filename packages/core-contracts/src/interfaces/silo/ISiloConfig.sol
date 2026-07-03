// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Full configuration of a single silo within a Silo V2 market
struct ConfigData {
    uint256 daoFee;
    uint256 deployerFee;
    address silo;
    address token;
    address protectedShareToken;
    address collateralShareToken;
    address debtShareToken;
    address solvencyOracle;
    address maxLtvOracle;
    address interestRateModel;
    uint256 maxLtv;
    uint256 lt;
    uint256 liquidationTargetLtv;
    uint256 liquidationFee;
    uint256 flashloanFee;
    address hookReceiver;
    bool callBeforeQuote;
}

/// @title ISiloConfig
/// @notice Interface for reading the configuration of silos in a Silo V2 market
interface ISiloConfig {
    /// @notice Returns the configuration data for a given silo
    /// @param _silo The silo address to query
    /// @return The silo's configuration data
    function getConfig(address _silo) external view returns (ConfigData memory);
}
