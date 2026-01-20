// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IHyperBeatPricer
 * @notice Interface for HyperBeat Pricer contract
 */
interface IHyperBeatPricer {
    /**
     * @notice Gets the vault token address
     * @return The address of the vault token
     */
    function vaultToken() external view returns (address);

    /**
     * @notice Gets the base asset address
     * @return The address of the base asset
     */
    function baseAsset() external view returns (address);

    /**
     * @notice Gets the current exchange rate
     * @return The current exchange rate
     */
    function getRate() external view returns (uint256);

    /**
     * @notice Gets the vault token amount for a given token and amount
     * @param _token The address of the token
     * @param _amount The amount of tokens
     * @return The amount of vault tokens
     */
    function getVaultTokenAmount(
        address _token,
        uint256 _amount
    ) external view returns (uint256);

    /**
     * @notice Gets the asset amount for a given vault token amount
     * @param _asset The address of the asset
     * @param _vaultTokenAmount The amount of vault tokens
     * @return The amount of assets
     */
    function getAssetAmount(
        address _asset,
        uint256 _vaultTokenAmount
    ) external view returns (uint256);
}
