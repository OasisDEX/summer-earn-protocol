// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAdmiralsQuartersErrors} from "../errors/IAdmiralsQuartersErrors.sol";
import {IAdmiralsQuartersEvents} from "../events/IAdmiralsQuartersEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IAdmiralsQuarters
 * @notice Interface for the AdmiralsQuarters contract, which manages interactions with FleetCommanders and token swaps
 */
interface IAdmiralsQuarters is
    IAdmiralsQuartersEvents,
    IAdmiralsQuartersErrors
{
    /**
     * @notice Returns the address of the 1inch router used for token swaps
     * @return The address of the 1inch router
     */
    function oneInchRouter() external view returns (address);

    /**
     * @notice Deposits tokens into the contract
     * @param asset The token to be deposited
     * @param amount The amount of tokens to deposit
     * @dev Emits a TokensDeposited event
     */
    function depositTokens(IERC20 asset, uint256 amount) external;

    /**
     * @notice Withdraws tokens from the contract
     * @param asset The token to be withdrawn
     * @param amount The amount of tokens to withdraw (0 for all)
     * @dev Emits a TokensWithdrawn event
     */
    function withdrawTokens(IERC20 asset, uint256 amount) external;

    /**
     * @notice Enters a FleetCommander by depositing tokens
     * @param fleetCommander The address of the FleetCommander contract
     * @param inputToken The token to be deposited
     * @param amount The amount of inputToken to be deposited (0 for all)
     * @return shares The number of shares received from the FleetCommander
     * @dev Emits a FleetEntered event
     */
    function enterFleet(
        address fleetCommander,
        IERC20 inputToken,
        uint256 amount
    ) external returns (uint256 shares);

    /**
     * @notice Exits a FleetCommander by withdrawing tokens
     * @param fleetCommander The address of the FleetCommander contract
     * @param amount The amount of shares to withdraw (0 for all)
     * @return assets The amount of assets received from the FleetCommander
     * @dev Emits a FleetExited event
     */
    function exitFleet(
        address fleetCommander,
        uint256 amount
    ) external returns (uint256 assets);

    /**
     * @notice Performs a token swap using 1inch Router
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amount The amount of fromToken to swap
     * @param minTokensReceived The minimum amount of toToken to receive after the swap
     * @param swapCalldata The calldata for the 1inch swap
     * @return swappedAmount The amount of toToken received after the swap
     * @dev Emits a Swapped event
     */
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 minTokensReceived,
        bytes calldata swapCalldata
    ) external returns (uint256 swappedAmount);

    /**
     * @notice Allows the owner to rescue any ERC20 tokens sent to the contract by mistake
     * @param token The address of the ERC20 token to rescue
     * @param to The address to send the rescued tokens to
     * @param amount The amount of tokens to rescue
     * @dev Can only be called by the contract owner
     * @dev Emits a TokensRescued event
     */
    function rescueTokens(IERC20 token, address to, uint256 amount) external;
}
