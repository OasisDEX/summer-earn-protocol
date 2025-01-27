// SPDX-License-Identifier: BUSL-1.1
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
     * @notice Deposits tokens into the contract
     * @param asset The token to be deposited
     * @param amount The amount of tokens to deposit
     * @dev Emits a TokensDeposited event
     */
    function depositTokens(IERC20 asset, uint256 amount) external payable;

    /**
     * @notice Withdraws tokens from the contract
     * @param asset The token to be withdrawn
     * @param amount The amount of tokens to withdraw (0 for all)
     * @dev Emits a TokensWithdrawn event
     */
    function withdrawTokens(IERC20 asset, uint256 amount) external payable;

    /**
     * @notice Enters a FleetCommander by depositing tokens
     * @param fleetCommander The address of the FleetCommander contract
     * @param assets The amount of inputToken to be deposited (0 for all)
     * @param receiver The address to receive the shares
     * @return shares The number of shares received from the FleetCommander
     * @dev Emits a FleetEntered event
     */
    function enterFleet(
        address fleetCommander,
        uint256 assets,
        address receiver
    ) external payable returns (uint256 shares);

    /**
     * @notice Stakes shares in a FleetCommander
     * @dev If zero shares are provided, the full balance of the FleetCommander is staked
     * @param fleetCommander The address of the FleetCommander contract
     * @param shares The amount of shares to stake
     * @dev Emits a FleetSharesStaked event
     */
    function stake(address fleetCommander, uint256 shares) external payable;

    /**
     * @notice Unstakes shares from a FleetCommander and withdraws assets to user wallet
     * @dev If zero shares are provided, the full balance of the FleetCommander is unstaked
     * @param fleetCommander The address of the FleetCommander contract
     * @param shares The amount of shares to unstake
     * @param claimRewards Whether to claim rewards before unstaking
     * @dev Emits a FleetSharesUnstaked event
     */
    function unstakeAndWithdrawAssets(
        address fleetCommander,
        uint256 shares,
        bool claimRewards
    ) external;

    /**
     * @notice Exits a FleetCommander by withdrawing tokens
     * @param fleetCommander The address of the FleetCommander contract
     * @param assets The amount of shares to withdraw (0 for all)
     * @return shares The amount of assets received from the FleetCommander
     * @dev Emits a FleetExited event
     */
    function exitFleet(
        address fleetCommander,
        uint256 assets
    ) external payable returns (uint256 shares);

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
    ) external payable returns (uint256 swappedAmount);

    /**
     * @notice Allows the owner to rescue any ERC20 tokens sent to the contract by mistake
     * @param token The address of the ERC20 token to rescue
     * @param to The address to send the rescued tokens to
     * @param amount The amount of tokens to rescue
     * @dev Can only be called by the contract owner
     * @dev Emits a TokensRescued event
     */
    function rescueTokens(IERC20 token, address to, uint256 amount) external;

    /**
     * @notice Imports a position from an ERC4626 vault to AdmiralsQuarters, has to be followed by a call to enter fleet
     * @dev If zero shares are provided, the full balance of the vault is imported
     * @dev needs approval from the user to withdraw on their behalf (e.g.
     * ERC4626Vault.approve(address(admiralsQuarters), type(uint256).max))
     * @param vault The address of the ERC4626 vault
     * @param shares The amount of vault tokens to import
     * @dev Emits an ERC4626PositionImported event
     */
    function moveFromERC4626ToAdmiralsQuarters(
        address vault,
        uint256 shares
    ) external;

    /**
     * @notice Imports a position from an Aave aToken to AdmiralsQuarters, has to be followed by a call to enter fleet
     * @dev If zero amount is provided, the full balance of the aToken is imported
     * @dev needs approval from the user to transfer from their wallet (e.g. aUSDC.approve(address(admiralsQuarters),
     * type(uint256).max))
     * @dev approval requires small buffer due to constant accrual of interest
     * @param aToken The address of the Aave aToken
     * @param amount The amount of tokens to import
     * @dev Emits an AavePositionImported event
     */
    function moveFromAaveToAdmiralsQuarters(
        address aToken,
        uint256 amount
    ) external;

    /**
     * @notice Imports a position from a Compound cToken to AdmiralsQuarters, has to be followed by a call to enter
     * fleet
     * @dev If zero amount is provided, the full balance of the cToken is imported
     * @dev needs approval from the user to withdraw on their behalf (e.g. cUSDC.allow(address(admiralsQuarters),true))
     *
     * @param cToken The address of the Compound cToken
     * @param amount The amount of tokens to import
     * @dev Emits a CompoundPositionImported event
     */
    function moveFromCompoundToAdmiralsQuarters(
        address cToken,
        uint256 amount
    ) external;

    /**
     * @notice Claims merkle rewards for a user
     * @param user Address to claim rewards for
     * @param indices Array of merkle proof indices
     * @param amounts Array of merkle proof amounts
     * @param proofs Array of merkle proof data
     * @param rewardsRedeemer Address of the rewards redeemer contract
     */
    function claimMerkleRewards(
        address user,
        uint256[] calldata indices,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs,
        address rewardsRedeemer
    ) external;

    /**
     * @notice Claims governance rewards
     * @param govRewardsManager Address of the governance rewards manager
     * @param rewardToken Address of the reward token to claim
     */
    function claimGovernanceRewards(
        address govRewardsManager,
        address rewardToken
    ) external;

    /**
     * @notice Claims rewards from fleet commanders
     * @param fleetCommanders Array of FleetCommander addresses
     * @param rewardToken Address of the reward token to claim
     */
    function claimFleetRewards(
        address[] calldata fleetCommanders,
        address rewardToken
    ) external;
}
