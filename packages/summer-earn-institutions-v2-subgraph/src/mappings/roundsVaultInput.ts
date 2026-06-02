import { log } from '@graphprotocol/graph-ts'
import {
  DepositWithReceipt,
  EmergencyRoundRolledBack,
  MinPositionSizeUpdated,
  RedeemReceipt,
  RedeemReceiptBatch,
  RoundAdvanced,
  RoundRetried,
  RoundSettled,
  TransferBatch,
  TransferSingle,
  WithdrawExchangeAsset,
  WithdrawExchangeAssetBatch,
} from '../../generated/templates/RoundsVaultInputTemplate/RoundsVaultInput'
import {
  applyDepositWithReceipt,
  applyEmergencyRollback,
  applyMinPositionSize,
  applyRoundAdvanced,
  applyRoundRetried,
  applyRoundSettled,
} from '../utils/lifecycle'
import {
  applyReceiptTransfer,
  markExchangeAssetRedemption,
  markExchangeAssetRedemptionBatch,
  markUnderlyingRedemption,
  markUnderlyingRedemptionBatch,
} from '../utils/receipt'

export function handleRoundAdvanced(event: RoundAdvanced): void {
  applyRoundAdvanced(event.address, event.params.roundId, event)
}

export function handleRoundSettled(event: RoundSettled): void {
  applyRoundSettled(
    event.address,
    event.params.roundId,
    event.params.exchangeRate.baseAmount,
    event.params.exchangeRate.quoteAmount,
    event,
  )
}

export function handleRoundRetried(event: RoundRetried): void {
  applyRoundRetried(event.address, event.params.roundId, event)
}

export function handleEmergencyRoundRolledBack(event: EmergencyRoundRolledBack): void {
  applyEmergencyRollback(event.address, event.params.roundId, event)
}

export function handleMinPositionSizeUpdated(event: MinPositionSizeUpdated): void {
  applyMinPositionSize(event.address, event.params.newMin, event)
}

export function handleDepositWithReceipt(event: DepositWithReceipt): void {
  applyDepositWithReceipt(
    event.address,
    event.params.id,
    event.params.caller,
    event.params.receiver,
    event.params.assets,
    event,
  )
}

export function handleRedeemReceipt(event: RedeemReceipt): void {
  markUnderlyingRedemption(
    event.address,
    event.params.caller,
    event.params.receiver,
    event.params.owner,
    event.params.id,
    event.params.amount,
    event,
    '',
  )
}

export function handleRedeemReceiptBatch(event: RedeemReceiptBatch): void {
  let ids = event.params.ids
  let amounts = event.params.amounts
  if (ids.length != amounts.length) {
    log.warning('RedeemReceiptBatch len mismatch on {}', [event.address.toHexString()])
    return
  }
  markUnderlyingRedemptionBatch(
    event.address,
    event.params.caller,
    event.params.receiver,
    event.params.owner,
    ids,
    amounts,
    event,
  )
}

export function handleWithdrawExchangeAsset(event: WithdrawExchangeAsset): void {
  markExchangeAssetRedemption(
    event.address,
    event.params.caller,
    event.params.receiver,
    event.params.owner,
    event.params.receiptId,
    event.params.receiptAmount,
    event.params.exchangeAssetAmount,
    event,
    '',
  )
}

export function handleWithdrawExchangeAssetBatch(event: WithdrawExchangeAssetBatch): void {
  let ids = event.params.receiptIds
  let amounts = event.params.receiptAmounts
  if (ids.length != amounts.length) {
    log.warning('WithdrawExchangeAssetBatch len mismatch on {}', [event.address.toHexString()])
    return
  }
  markExchangeAssetRedemptionBatch(
    event.address,
    event.params.caller,
    event.params.receiver,
    event.params.owner,
    ids,
    amounts,
    event.params.exchangeAssetAmount,
    event,
  )
}

export function handleTransferSingle(event: TransferSingle): void {
  applyReceiptTransfer(
    event.address,
    event.params.operator,
    event.params.from,
    event.params.to,
    event.params.id,
    event.params.value,
    event,
    0,
  )
}

export function handleTransferBatch(event: TransferBatch): void {
  let ids = event.params.ids
  let values = event.params.values
  for (let i = 0; i < ids.length; i++) {
    applyReceiptTransfer(
      event.address,
      event.params.operator,
      event.params.from,
      event.params.to,
      ids[i],
      values[i],
      event,
      i as i32,
    )
  }
}
