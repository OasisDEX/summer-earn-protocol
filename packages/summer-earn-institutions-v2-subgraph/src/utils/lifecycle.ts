import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { Round } from '../../generated/schema'
import { getOrCreateRound, getRoundsVaultByAddress } from '../common/initializers'
import { BigIntConstants } from '../common/constants'
import { exchangeRateAsDecimal } from './price'
import { refreshSnapshots } from './snapshots'

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
  closingRound.totalReceiptSupplyAtClose = vault.currentRoundReceiptSupply
  closingRound.save()

  vault.currentRound = closingRoundId.plus(BigIntConstants.ONE)
  vault.currentRoundReceiptSupply = BigIntConstants.ZERO
  vault.save()

  let newRound = getOrCreateRound(vault, vault.currentRound, event.block)
  newRound.state = 'OPENED'
  newRound.save()

  refreshSnapshots(vault, vault.pendingSettlementAmount, null, event.block)
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
  round.exchangeRateDecimal = exchangeRateAsDecimal(rateBase, rateQuote)
  round.save()

  // Receipts that were pending for this round are now redeemable, so they
  // leave the "pending settlement" bucket.
  vault.pendingSettlementAmount = vault.pendingSettlementAmount.minus(
    round.totalReceiptSupplyAtClose,
  )
  if (vault.pendingSettlementAmount.lt(BigIntConstants.ZERO)) {
    vault.pendingSettlementAmount = BigIntConstants.ZERO
  }
  vault.save()

  refreshSnapshots(vault, vault.pendingSettlementAmount, round.exchangeRateDecimal, event.block)
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
  round.retriedCount = round.retriedCount + 1
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
  // The on-chain state transitions from InSettlement back to Opened; surface
  // it as ROLLED_BACK so consumers can distinguish a fresh open from a
  // recovered one. Receipts remain redeemable until the keeper retries.
  round.state = 'ROLLED_BACK'
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
  assets: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  // DepositWithReceipt fires on every deposit, regardless of round outcome.
  vault.cumulativeDepositsQueued = vault.cumulativeDepositsQueued.plus(assets)
  vault.save()
}

export function loadRound(vaultId: string, roundId: BigInt): Round | null {
  return Round.load(vaultId + '-' + roundId.toString())
}
