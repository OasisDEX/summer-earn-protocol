// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VaultPriceState, VaultAccruals} from "./Types.sol";

/// @title IPriceAndFeeCalculator
/// @notice Interface for the unit price provider
interface IPriceAndFeeCalculator {
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    error Aera__StalePrice();
    error Aera__TimestampMustBeAfterLastUpdate();
    error Aera__TimestampCantBeInFuture();
    error Aera__ZeroAddressOracleRegistry();
    error Aera__InvalidMaxPriceToleranceRatio();
    error Aera__InvalidMinPriceToleranceRatio();
    error Aera__InvalidMaxPriceAge();
    error Aera__InvalidMaxUpdateDelayDays();
    error Aera__ThresholdNotSet();
    error Aera__VaultPaused();
    error Aera__VaultNotPaused();
    error Aera__UnitPriceMismatch();
    error Aera__TimestampMismatch();
    error Aera__VaultAlreadyInitialized();
    error Aera__VaultNotInitialized();
    error Aera__InvalidPrice();
    error Aera__CurrentPriceAboveHighestPrice();
    ////////////////////////////////////////////////////////////
    //                       Functions                        //
    ////////////////////////////////////////////////////////////

    /// @notice Set the initial price state for the vault
    /// @param vault Address of the vault
    /// @param price New unit price
    /// @param timestamp Timestamp when the price was measured
    function setInitialPrice(
        address vault,
        uint128 price,
        uint32 timestamp
    ) external;

    /// @notice Set vault thresholds
    /// @param vault Address of the vault
    /// @param minPriceToleranceRatio Minimum ratio (of a price decrease) in basis points
    /// @param maxPriceToleranceRatio Maximum ratio (of a price increase) in basis points
    /// @param minUpdateIntervalMinutes The minimum interval between updates in minutes
    /// @param maxPriceAge Max delay between when a vault was priced and when the price is acceptable
    /// @param maxUpdateDelayDays Max delay between two price updates
    function setThresholds(
        address vault,
        uint16 minPriceToleranceRatio,
        uint16 maxPriceToleranceRatio,
        uint16 minUpdateIntervalMinutes,
        uint8 maxPriceAge,
        uint8 maxUpdateDelayDays
    ) external;

    /// @notice Set the unit price for the vault in numeraire terms
    /// @param vault Address of the vault
    /// @param price New unit price
    /// @param timestamp Timestamp when the price was measured
    function setUnitPrice(
        address vault,
        uint128 price,
        uint32 timestamp
    ) external;

    /// @notice Pause the vault
    /// @param vault Address of the vault
    function pauseVault(address vault) external;

    /// @notice Unpause the vault
    /// @param vault Address of the vault
    /// @param price Expected price of the last update
    /// @param timestamp Expected timestamp of the last update
    /// @dev MUST revert if price or timestamp don't exactly match last update
    function unpauseVault(
        address vault,
        uint128 price,
        uint32 timestamp
    ) external;

    /// @notice Resets the highest price for a vault to the current price
    /// @param vault Address of the vault
    function resetHighestPrice(address vault) external;

    /// @notice Convert units to token amount
    /// @param vault Address of the vault
    /// @param token Address of the token
    /// @param unitsAmount Amount of units
    /// @return tokenAmount Amount of tokens
    function convertUnitsToToken(
        address vault,
        IERC20 token,
        uint256 unitsAmount
    ) external view returns (uint256 tokenAmount);

    /// @notice Convert units to token amount if vault is not paused
    /// @param vault Address of the vault
    /// @param token Address of the token
    /// @param unitsAmount Amount of units
    /// @param rounding The rounding mode
    /// @return tokenAmount Amount of tokens
    /// @dev MUST revert if vault is paused
    function convertUnitsToTokenIfActive(
        address vault,
        IERC20 token,
        uint256 unitsAmount,
        Math.Rounding rounding
    ) external view returns (uint256 tokenAmount);

    /// @notice Convert token amount to units
    /// @param vault Address of the vault
    /// @param token Address of the token
    /// @param tokenAmount Amount of tokens
    /// @return unitsAmount Amount of units
    function convertTokenToUnits(
        address vault,
        IERC20 token,
        uint256 tokenAmount
    ) external view returns (uint256 unitsAmount);

    /// @notice Convert token amount to units if vault is not paused
    /// @param vault Address of the vault
    /// @param token Address of the token
    /// @param tokenAmount Amount of tokens
    /// @param rounding The rounding mode
    /// @return unitsAmount Amount of units
    /// @dev MUST revert if vault is paused
    function convertTokenToUnitsIfActive(
        address vault,
        IERC20 token,
        uint256 tokenAmount,
        Math.Rounding rounding
    ) external view returns (uint256 unitsAmount);

    /// @notice Convert units to numeraire token amount
    /// @param vault Address of the vault
    /// @param unitsAmount Amount of units
    /// @return numeraireAmount Amount of numeraire
    function convertUnitsToNumeraire(
        address vault,
        uint256 unitsAmount
    ) external view returns (uint256 numeraireAmount);

    /// @notice Returns the age of the last submitted price for a vault
    /// @param vault Address of the vault
    /// @return priceAge The difference between block.timestamp and vault's unit price timestamp
    function getVaultsPriceAge(address vault) external view returns (uint256);

    /// @notice Check if a vault is paused
    /// @param vault The address of the vault
    /// @return True if the vault is paused, false otherwise
    function isVaultPaused(address vault) external view returns (bool);

    function getVaultState(
        address vault
    ) external view returns (VaultPriceState memory, VaultAccruals memory);
}
