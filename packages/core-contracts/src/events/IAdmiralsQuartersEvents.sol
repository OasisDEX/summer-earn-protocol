// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IAdmiralsQuartersEvents
 * @dev Interface for the events emitted by the AdmiralsQuarters contract.
 * @notice This interface defines the events that can be emitted during various operations
 * in the AdmiralsQuarters contract, such as token deposits, withdrawals, fleet interactions,
 * token swaps, and rescue operations.
 */
interface IAdmiralsQuartersEvents {
    /**
     * @dev Emitted when tokens are deposited into the AdmiralsQuarters.
     * @param user The address of the user who deposited the tokens.
     * @param token The address of the token that was deposited.
     * @param amount The amount of tokens that were deposited.
     */
    event TokensDeposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    /**
     * @dev Emitted when tokens are withdrawn from the AdmiralsQuarters.
     * @param user The address of the user who withdrew the tokens.
     * @param token The address of the token that was withdrawn.
     * @param amount The amount of tokens that were withdrawn.
     */
    event TokensWithdrawn(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    /**
     * @dev Emitted when a user enters a fleet with their tokens.
     * @param user The address of the user who entered the fleet.
     * @param fleetCommander The address of the FleetCommander contract.
     * @param inputAmount The amount of tokens the user input into the fleet.
     * @param sharesReceived The amount of shares the user received in return.
     */
    event FleetEntered(
        address indexed user,
        address indexed fleetCommander,
        uint256 inputAmount,
        uint256 sharesReceived
    );

    /**
     * @dev Emitted when a user exits a fleet, withdrawing their tokens.
     * @param user The address of the user who exited the fleet.
     * @param fleetCommander The address of the FleetCommander contract.
     * @param withdrawnAmount The amount of shares withdrawn from the fleet.
     * @param outputAmount The amount of tokens received in return.
     */
    event FleetExited(
        address indexed user,
        address indexed fleetCommander,
        uint256 withdrawnAmount,
        uint256 outputAmount
    );

    /**
     * @dev Emitted when a user stakes their fleet shares.
     * @param user The address of the user who staked their shares.
     * @param fleetCommander The address of the FleetCommander contract.
     * @param amount The amount of shares staked.
     */
    event FleetSharesStaked(
        address indexed user,
        address indexed fleetCommander,
        uint256 amount
    );

    /**
     * @dev Emitted when a user unstakes their fleet shares.
     * @param user The address of the user who unstaked their shares.
     * @param fleetCommander The address of the FleetCommander contract.
     * @param amount The amount of shares unstaked.
     */
    event FleetSharesUnstaked(
        address indexed user,
        address indexed fleetCommander,
        uint256 amount
    );

    /**
     * @dev Emitted when a token swap occurs.
     * @param user The address of the user who performed the swap.
     * @param fromToken The address of the token being swapped from.
     * @param toToken The address of the token being swapped to.
     * @param fromAmount The amount of tokens swapped from.
     * @param toAmount The amount of tokens received in the swap.
     */
    event Swapped(
        address indexed user,
        address indexed fromToken,
        address indexed toToken,
        uint256 fromAmount,
        uint256 toAmount
    );

    /**
     * @dev Emitted when tokens are rescued from the contract by the owner.
     * @param token The address of the token that was rescued.
     * @param to The address that received the rescued tokens.
     * @param amount The amount of tokens that were rescued.
     */
    event TokensRescued(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    /**
     * @dev Emitted when a user's compound position is imported.
     * @param user The address of the user whose position is imported.
     * @param cToken The address of the cToken being imported.
     * @param amount The amount of tokens being imported.
     */
    event CompoundPositionImported(
        address indexed user,
        address indexed cToken,
        uint256 amount
    );

    /**
     * @dev Emitted when a user's aave position is imported.
     * @param user The address of the user whose position is imported.
     * @param aToken The address of the aToken being imported.
     * @param amount The amount of tokens being imported.
     */
    event AavePositionImported(
        address indexed user,
        address indexed aToken,
        uint256 amount
    );

    /**
     * @dev Emitted when a user's erc4626 position is imported.
     * @param user The address of the user whose position is imported.
     * @param vault The address of the vault being imported.
     * @param amount The amount of tokens being imported.
     */
    event ERC4626PositionImported(
        address indexed user,
        address indexed vault,
        uint256 amount
    );
}
