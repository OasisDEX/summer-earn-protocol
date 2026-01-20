// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title IHyperBeatVaultToken
 * @notice Interface for HyperBeat Vault Token (similar to IMToken)
 */
interface IHyperBeatVaultToken is IERC20 {
    /**
     * @notice Mints vault tokens to a given address
     * @param to Address to mint tokens to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burns vault tokens from a given address
     * @param from Address to burn tokens from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external;

    /**
     * @notice Returns the total supply of vault tokens
     * @return The total supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Returns the decimals of the vault token
     * @return The decimals of the vault token
     */
    function decimals() external view returns (uint8);
}
