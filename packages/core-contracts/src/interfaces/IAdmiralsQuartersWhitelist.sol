// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAdmiralsQuartersErrors} from "../errors/IAdmiralsQuartersErrors.sol";
import {IAdmiralsQuartersEvents} from "../events/IAdmiralsQuartersEvents.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureTransfer} from "../interfaces/permit2/IPermit2.sol";

/**
 * @title IAdmiralsQuartersWhitelist
 * @notice Interface for the AdmiralsQuartersWhitelist contract, which manages interactions with FleetCommanders and token swaps
 * @notice only whitelisted accounts can use the contract
 */
interface IAdmiralsQuartersWhitelist is
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
     * @param assets The amount of the FleetCommander's underlying asset to deposit (0 means use
     *               the contract's full balance of the underlying)
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
     * @notice Enters a FleetCommander by depositing tokens using Permit2 witness transfers
     * @param owner The address of the token owner
     * @param fleetCommander The address of the FleetCommander contract
     * @param assets The exact amount of the FleetCommander's underlying to deposit; must equal
     *               `permitData.permitted.amount` (passing `0` is not supported unless the
     *               signature itself was issued for `0`)
     * @param _referralCode Reserved for ABI parity with the public (non-whitelist) variant. This
     *                     implementation ignores the value on-chain and substitutes `bytes32(0)`
     *                     into the witness payload. SDKs and frontends MUST sign with a zero-value
     *                     referral for signature compatibility.
     * @param receiver The address to receive the shares
     * @param permitData The permit2 data
     * @param signature The signature for permit2
     * @return shares The number of shares received from the FleetCommander
     * @dev Emits a FleetEntered event
     */
    function enterFleetWithPermit2(
        address owner,
        address fleetCommander,
        uint256 assets,
        bytes calldata _referralCode,
        address receiver,
        ISignatureTransfer.PermitTransferFrom calldata permitData,
        bytes calldata signature
    ) external payable returns (uint256 shares);

    /**
     * @notice Exits a FleetCommander by withdrawing the underlying asset
     * @param fleetCommander The address of the FleetCommander contract
     * @param assets The amount of the FleetCommander's underlying asset to withdraw (0 withdraws
     *               the caller's full share balance)
     * @return shares The number of FleetCommander shares burnt to satisfy the withdrawal
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
     * @param assets The amount of fromToken to swap
     * @param minTokensReceived The minimum amount of toToken to receive after the swap
     * @param swapCalldata The calldata for the 1inch swap
     * @return swappedAmount The amount of toToken received after the swap
     * @dev Emits a Swapped event
     */
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 assets,
        uint256 minTokensReceived,
        bytes calldata swapCalldata
    ) external payable returns (uint256 swappedAmount);

    /**
     * @notice Allows the owner to rescue ERC20 tokens or native ETH sent to the contract by mistake
     * @dev When `token` equals `NATIVE_PSEUDO_ADDRESS`, the contract forwards native ETH (using
     *      the contract's full ETH balance when `amount == 0`); otherwise it forwards `amount` of
     *      the ERC20.
     * @param token The address of the ERC20 token to rescue, or `NATIVE_PSEUDO_ADDRESS` for ETH
     * @param to The address to send the rescued tokens to
     * @param amount The amount of tokens to rescue (ignored for native ETH when `0`, which sends
     *               the full balance)
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
     * @param assets The amount of aToken to import
     * @dev Emits an AavePositionImported event
     */
    function moveFromAaveToAdmiralsQuarters(
        address aToken,
        uint256 assets
    ) external;

    /**
     * @notice Imports a position from a Compound cToken to AdmiralsQuarters, has to be followed by a call to enter
     * fleet
     * @dev If zero amount is provided, the full balance of the cToken is imported
     * @dev needs approval from the user to withdraw on their behalf (e.g. cUSDC.allow(address(admiralsQuarters),true))
     *
     * @param cToken The address of the Compound cToken
     * @param assets The amount of cToken balance to import
     * @dev Emits a CompoundPositionImported event
     */
    function moveFromCompoundToAdmiralsQuarters(
        address cToken,
        uint256 assets
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
}
