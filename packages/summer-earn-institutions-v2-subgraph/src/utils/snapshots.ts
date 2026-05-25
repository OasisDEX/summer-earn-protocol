import { BigDecimal, BigInt, ethereum } from '@graphprotocol/graph-ts'
import {
  RoundsVault,
  RoundsVaultDailySnapshot,
  RoundsVaultHourlySnapshot,
} from '../../generated/schema'
import { SECONDS_PER_DAY, SECONDS_PER_HOUR } from '../common/constants'

export function refreshSnapshots(
  vault: RoundsVault,
  pendingSettlementAmount: BigInt,
  lastSettledRate: BigDecimal | null,
  block: ethereum.Block,
): void {
  let timestamp = block.timestamp
  let day = timestamp.toI32() / SECONDS_PER_DAY
  let hour = timestamp.toI32() / SECONDS_PER_HOUR

  let dailyId = vault.id + '-' + day.toString()
  let daily = RoundsVaultDailySnapshot.load(dailyId)
  if (daily == null) {
    daily = new RoundsVaultDailySnapshot(dailyId)
    daily.vault = vault.id
    daily.day = BigInt.fromI32(day)
  }
  daily.timestamp = timestamp
  daily.cumulativeDepositsQueued = vault.cumulativeDepositsQueued
  daily.cumulativeExchangeAssetWithdrawn = vault.cumulativeExchangeAssetWithdrawn
  daily.pendingSettlementAmount = pendingSettlementAmount
  daily.currentRound = vault.currentRound
  if (lastSettledRate !== null) {
    daily.lastSettledExchangeRate = lastSettledRate
  }
  daily.save()

  let hourlyId = vault.id + '-' + hour.toString()
  let hourly = RoundsVaultHourlySnapshot.load(hourlyId)
  if (hourly == null) {
    hourly = new RoundsVaultHourlySnapshot(hourlyId)
    hourly.vault = vault.id
    hourly.hour = BigInt.fromI32(hour)
  }
  hourly.timestamp = timestamp
  hourly.cumulativeDepositsQueued = vault.cumulativeDepositsQueued
  hourly.cumulativeExchangeAssetWithdrawn = vault.cumulativeExchangeAssetWithdrawn
  hourly.pendingSettlementAmount = pendingSettlementAmount
  hourly.currentRound = vault.currentRound
  if (lastSettledRate !== null) {
    hourly.lastSettledExchangeRate = lastSettledRate
  }
  hourly.save()
}

