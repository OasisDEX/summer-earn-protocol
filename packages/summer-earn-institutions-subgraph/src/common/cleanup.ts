import { BigInt, store } from '@graphprotocol/graph-ts'
import { getHourlyTimestamp } from '../utils/vaultRateHandlers'
import { BigIntConstants } from './constants'

const SNAPSHOT_RETENTION_PERIOD = BigInt.fromI32(30 * 24 * 60 * 60) // 30 days in seconds
const DEEP_CLEAN_LOOKBACK_PERIOD = BigInt.fromI32(365 * 24 * 60 * 60) // 1 year in seconds

export function removeOldPositionHourlySnapshot(
  positionId: string,
  currentTimestamp: BigInt,
): void {
  // PositionHourlySnapshot ID: positionId + '-' + getHourlyTimestamp(timestamp)
  // getHourlyTimestamp returns the start of the hour.

  const currentHourTimestamp = getHourlyTimestamp(currentTimestamp)
  const oldHourTimestamp = currentHourTimestamp.minus(SNAPSHOT_RETENTION_PERIOD)

  const id = positionId + '-' + oldHourTimestamp.toString()
  store.remove('PositionHourlySnapshot', id)
}

export function deepCleanPositionHourlySnapshots(
  positionId: string,
  currentTimestamp: BigInt,
): void {
  const currentHourTimestamp = getHourlyTimestamp(currentTimestamp)
  const startHourTimestamp = currentHourTimestamp.minus(SNAPSHOT_RETENTION_PERIOD)
  const endHourTimestamp = currentHourTimestamp.minus(DEEP_CLEAN_LOOKBACK_PERIOD)
  // Iterate backwards from retention time to 1 year ago
  let timestamp = startHourTimestamp
  while (timestamp.ge(endHourTimestamp)) {
    const id = positionId + '-' + timestamp.toString()
    store.remove('PositionHourlySnapshot', id)
    timestamp = timestamp.minus(BigIntConstants.SECONDS_PER_HOUR)
  }
}
