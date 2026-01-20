// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IHyperBeatPricer.sol";
import "./IHyperBeatVaultToken.sol";

/**
 * @title IHyperBeatDepositor
 * @notice Interface for HyperBeat Depositor contract
 */
interface IHyperBeatDepositor {
    /**
     * @notice Deposits tokens into the vault
     * @param _token The address of the token
     * @param _receiver The address of the receiver
     * @param _amount The amount of tokens to deposit
     * @param _builderCode The builder code
     */
    function deposit(
        address _token,
        address _receiver,
        uint256 _amount,
        bytes32 _builderCode
    ) external;

    /**
     * @notice Gets the vault token address
     * @return The address of the vault token
     */
    function vaultToken() external view returns (address);

    /**
     * @notice Gets the pricer address
     * @return The address of the pricer
     */
    function pricer() external view returns (IHyperBeatPricer);
}
