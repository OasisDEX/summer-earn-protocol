import { BigInt, log } from '@graphprotocol/graph-ts'
import {
  DepositWithReceipt,
  EmergencyRoundRolledBack,
  MinPositionSizeUpdated,
  RoundAdvanced,
  RoundRetried,
  RoundSettled,
  SharesRedeemed,
  TransferBatch,
  TransferSingle,
  WithdrawExchangeAsset,
  WithdrawExchangeAssetBatch,
} from '../../generated/templates/RoundsVaultOutputTemplate/RoundsVaultOutput'
import { getRoundsVaultByAddress } from '../common/initializers'
import { BigIntConstants } from '../common/constants'
import {
  applyDepositWithReceipt,
  applyEmergencyRollback,
  applyMinPositionSize,
  applyRoundAdvanced,
  applyRoundRetried,
  applyRoundSettled,
  loadRound,
} from '../utils/lifecycle'
import { applyReceiptTransfer, markExchangeAssetRedemption } from '../utils/receipt'

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
  applyDepositWithReceipt(event.address, event.params.id, event.params.assets, event)
}

export function handleSharesRedeemed(event: SharesRedeemed): void {
  let vault = getRoundsVaultByAddress(event.address)
  if (vault == null) return
  let round = loadRound(vault.id, event.params.roundId)
  if (round == null) return
  round.outputSharesRedeemed = event.params.shares
  round.outputAssetsReturned = event.params.assets
  round.save()
}

export function handleWithdrawExchangeAsset(event: WithdrawExchangeAsset): void {
  markExchangeAssetRedemption(
    event.address,
    event.params.owner,
    event.params.receiptId,
    event.params.receiptAmount,
    event.params.exchangeAssetAmount,
    event,
  )
}

export function handleWithdrawExchangeAssetBatch(event: WithdrawExchangeAssetBatch): void {
  let ids = event.params.receiptIds
  let amounts = event.params.receiptAmounts
  if (ids.length != amounts.length) {
    log.warning('WithdrawExchangeAssetBatch len mismatch on {}', [
      event.address.toHexString(),
    ])
    return
  }
  let total = event.params.exchangeAssetAmount
  for (let i = 0; i < ids.length; i++) {
    let exchangeForThisRow: BigInt
    if (i == 0) {
      exchangeForThisRow = total
    } else {
      exchangeForThisRow = BigIntConstants.ZERO
    }
    markExchangeAssetRedemption(
      event.address,
      event.params.owner,
      ids[i],
      amounts[i],
      exchangeForThisRow,
      event,
    )
  }
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
