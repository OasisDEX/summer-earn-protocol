// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import "../../interfaces/extensions/ERC4626MultiTokenWrapper/IERC4626MultiTokenWrapper.sol";

import "./IRoundsVaultBaseErrors.sol";
import "./IRoundsVaultBaseEvents.sol";

/**
    @title RoundsVaultBase

    @notice Provides a way of investing in a target tokenized vault that has investment periods in 
    which the vault is locked. During these locked periods, the vault does not accept deposits, so
    investors need to be on the lookout for the unlocked period to deposit their funds.

    Instead this contract allows investors to deposit their funds at any point in time. In exchange
    they receive a tokenized receipt that is tied to the investment round and contains the amount of
    assets deposited.

    On each round transition, this contract will use the available funds to deposit them into the
    target vault, getting an exchange asset in return. This exchange asset is typically the target
    vault shares when the underlying asset of this vault is the same as the underlying asset of the
    target vault. Otherwise, the exchange asset is the target vault underlying asset.

    The receipts belonging to the current round can always be redeemed immediately for the underlying
    token. 

    The user can also decide to exchange the receipts belonging to previous rounds for the ERC-20 exchange
    asset kept in this contract. The exchange asset can be immediately witdrawn by burning the corresponding
    receipts.

    This contract tracks the current round and also stores the shares price of the each finished round. This
    share price is used to calculate the amount of shares that the user will receive when redeeming a receipt
    for a finished round
            
    @author Roberto Cano <robercano>
 */
interface IRoundsVaultBase is IERC4626MultiTokenWrapper {
    // PUBLIC FUNCTIONS

    /**
        @notice Closes the current round and starts the next one. This freezes the amount
        of assets/shares to be settled for the current round.
     
        @dev Only the keeper can call this function
     */
    function nextRound() external;

    /**
        @notice Redeems a receipt for a certain amount of target vault shares. The amount of shares is
                calculated based on the receipt's round share price and the amount of underlying tokens
                that the receipt represents

        @param id The id of the receipt to be redeemed
        @param amount The amount of the receipt to be redeemed
        @param receiver The address that will receive the target vault shares
        @param owner The address that owns the receipt, in case the caller is not the owner
     */
    function redeemExchangeAsset(
        uint256 id,
        uint256 amount,
        address receiver,
        address owner
    ) external returns (uint256);

    /**
        @notice Same functionality as { redeemForShares } but for multiple receipts at the once

        @dev See { redeemForShares } for more details
     */
    function redeemExchangeAssetBatch(
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
        @notice Returns the current round number
     */
    function getCurrentRound() external view returns (uint256);

    /**
        @notice Returns the asset used for the exchange
     */
    function exchangeAsset() external view returns (address);

    /**
        @notice Returns the exchange rate for the underlying to the exchange asset for a given round

        @dev It gives the amount of exchange asset that can be obtained for 1 underlying token, with the
        exchange asset decimals
     */
    function getExchangeRate(
        uint256 round
    ) external view returns (Price memory);

    /**
        @notice Executes the settlement trade for a specific round that is in the InSettlement state.
                Snapshots the final exchange rate based on actual trade results.
     
        @param roundId The id of the round to be settled
 
        @dev Only the keeper can call this function
     */
    function setRoundSettled(uint256 roundId) external;

    /**
        @notice Executes the settlement trade for a batch of rounds that are in the InSettlement state.
                Snapshots the final exchange rate based on actual trade results.
     
        @param roundIds The ids of the rounds to be settled
 
        @dev Only the keeper can call this function
     */
    function setRoundSettledBatch(uint256[] calldata roundIds) external;

    /**
        @notice Returns the minimum aggregate position size for a user to enter or exit
     */
    function minPositionSize() external view returns (uint256);

    /**
        @notice Sets the minimum aggregate position size for a user to enter or exit
     
        @param minSize The new minimum position size
     */
    function setMinPositionSize(uint256 minSize) external;

    /**
        @notice Forces a round that is stuck in the InSettlement state back to the Opened state.
                This assumes that the operation to settle the round via _operate failed and liquidity needs 
                to be categorized back to bypass the lock step.
        @param roundId The ID of the round to be rolled back
        @dev Only the governor can call this function.
     */
    function emergencyRollbackRound(uint256 roundId) external;

    /**
        @notice Retries a stuck round by putting it back into InSettlement from Opened state.
        
        @param roundId The ID of the round to retry.
        @dev Only the keeper can call this function.
     */
    function retryRound(uint256 roundId) external;
}
