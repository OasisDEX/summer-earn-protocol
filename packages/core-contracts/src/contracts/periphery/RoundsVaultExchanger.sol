// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import "../../interfaces/rounds-vault/IRoundsVaultBase.sol";

/**
    @notice This helper contract allows the user to exchange a receipt from the RoundsVaultInput
    for a ticket from the RoundsVaultOutput. This is done by burning the receipt in exchange
    for the corresponding amount of the main vault shares in the RoundsVaultInput, and then
    depositing this shares into the RoundsVaultOutput, which will mint the corresponding
    receipt to the user.

    After this operation is completed, the user has a receipt that can be exchanged for the main vaults
    underlying once the current round is over.
 */
contract RoundsVaultExchanger is Context {
    /**
      @notice Exchanges a receipt from the RoundsVaultInput for a receipt from
      the RoundsVaultOutput by redeeming the input receipt in the input vault for
      shares and then depositing these shares into the output vault in exchange for an output
      receipt

      @param inputVault The address of the RoundsVaultInput
      @param outputVault The address of the RoundsVaultOutput
      @param id The id of the receipt to exchange
      @param amount The amount of the receipt to exchange

      @dev The receipt must be for a previous round. If it is for the current round
      the transaction will revert

      @return The amount of shares deposited in the output vault
    */
    function exchangeInputForOutput(
        IRoundsVaultBase inputVault,
        IRoundsVaultBase outputVault,
        uint256 id,
        uint256 amount
    ) external returns (uint256) {
        uint256 sharesAmount = inputVault.redeemExchangeAsset(
            id,
            amount,
            address(this),
            _msgSender()
        );

        SafeERC20.forceApprove(
            IERC20(inputVault.exchangeAsset()),
            address(outputVault),
            sharesAmount
        );

        return outputVault.deposit(sharesAmount, _msgSender());
    }

    /**
      @notice Exchanges a list of receipts from the RoundsVaultInput for a receipt from
      the RoundsVaultOutput by redeeming the input receipts in the input vault for
      shares and then depositing these shares into the output vault in exchange for an output
      receipt

      @param inputVault The address of the RoundsVaultInput
      @param outputVault The address of the RoundsVaultOutput
      @param ids The ids of the receipts to exchange
      @param amounts The amounts of the receipts to exchange

      @dev All receipts must be for a previous round. If any of the receipts is for the current round
      the transaction will revert

      @return The amount of shares deposited in the output vault
    */
    function exchangeInputForOutputBatch(
        IRoundsVaultBase inputVault,
        IRoundsVaultBase outputVault,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external returns (uint256) {
        uint256 sharesAmount = inputVault.redeemExchangeAssetBatch(
            ids,
            amounts,
            address(this),
            _msgSender()
        );

        SafeERC20.forceApprove(
            IERC20(inputVault.exchangeAsset()),
            address(outputVault),
            sharesAmount
        );

        return outputVault.deposit(sharesAmount, _msgSender());
    }
}
