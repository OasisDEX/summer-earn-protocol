import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { Round } from '../../generated/schema'
import { getOrCreateRound, getRoundsVaultByAddress } from '../common/initializers'
import { BigIntConstants } from '../common/constants'
import { exchangeRateAsDecimal } from './price'

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
  round.exchangeRateDecimal = exchangeRateAsDecimal(rateBase, rateQuote)
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
  assets: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  let round = getOrCreateRound(vault, roundId, event.block)
  round.depositsQueued = round.depositsQueued.plus(assets)
  round.save()
}

export function loadRound(vaultId: string, roundId: BigInt): Round | null {
  return Round.load(vaultId + '-' + roundId.toString())
}
