import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import {
  getOrCreateAccount,
  getOrCreateReceipt,
  getOrCreateRound,
  getRoundsVaultByAddress,
} from '../common/initializers'
import { BigIntConstants } from '../common/constants'
import { recordReceiptActivity, ReceiptActivityTypeStr } from './receipt'

export function applyRoundAdvanced(
  vaultAddr: Address,
  closingRoundId: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) {
    log.warning('RoundAdvanced for unknown vault {}', [vaultAddr.toHexString()])
    return
  }

  let closingRound = getOrCreateRound(vault, closingRoundId, event.block)
  closingRound.state = 'IN_SETTLEMENT'
  closingRound.closedAt = event.block.timestamp
  closingRound.closedAtBlock = event.block.number
  closingRound.save()

  vault.currentRound = closingRoundId.plus(BigIntConstants.ONE)
  vault.save()

  let newRound = getOrCreateRound(vault, vault.currentRound, event.block)
  newRound.state = 'OPENED'
  newRound.save()
}

export function applyRoundSettled(
  vaultAddr: Address,
  roundId: BigInt,
  rateBase: BigInt,
  rateQuote: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return

  let round = getOrCreateRound(vault, roundId, event.block)
  round.state = 'SETTLED'
  round.settledAt = event.block.timestamp
  round.settledAtBlock = event.block.number
  round.exchangeRateBase = rateBase
  round.exchangeRateQuote = rateQuote
  // Empty rounds settle with a fallback preview rate (non-zero quote), so detect "empty" from the
  // receipt supply at settlement time, not from the rate.
  round.isEmpty = round.receiptSupply.equals(BigIntConstants.ZERO)
  round.save()
}

export function applyRoundRetried(
  vaultAddr: Address,
  roundId: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  let round = getOrCreateRound(vault, roundId, event.block)
  round.state = 'IN_SETTLEMENT'
  round.save()
}

export function applyEmergencyRollback(
  vaultAddr: Address,
  roundId: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  let round = getOrCreateRound(vault, roundId, event.block)
  // On chain the round transitions InSettlement → Opened. Mirror that exactly
  // and record the historical fact via `rolledBack`.
  round.state = 'OPENED'
  round.rolledBack = true
  round.save()
}

export function applyMinPositionSize(
  vaultAddr: Address,
  newMin: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  vault.minPositionSize = newMin
  vault.save()
}

export function applyDepositWithReceipt(
  vaultAddr: Address,
  roundId: BigInt,
  caller: Address,
  receiver: Address,
  assets: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  let round = getOrCreateRound(vault, roundId, event.block)
  let user = getOrCreateAccount(receiver.toHexString())
  let receipt = getOrCreateReceipt(vault, round, user, event.block)
  // Receipts are minted 1:1 with the deposited asset, so receiptAmount == assetAmount == assets.
  // The receipt balance itself is booked by the paired ERC-1155 mint in applyReceiptTransfer.
  recordReceiptActivity(
    vault,
    round,
    receipt,
    user,
    ReceiptActivityTypeStr.DEPOSIT(),
    caller,
    receiver,
    assets,
    assets,
    vault.underlyingToken,
    event,
    '',
  )
}
