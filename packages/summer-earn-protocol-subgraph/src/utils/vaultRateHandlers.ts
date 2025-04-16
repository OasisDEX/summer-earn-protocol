import { Address, BigDecimal, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { DailyInterestRate, HourlyInterestRate, WeeklyInterestRate } from '../../generated/schema'
import { BigDecimalConstants, BigIntConstants } from '../common/constants'
import { getOrCreateVault } from '../common/initializers'

class DailyVaultRateResult {
  constructor(
    public dailyRateId: string,
    public dayTimestamp: BigInt,
  ) {}
}

class HourlyVaultRateResult {
  constructor(
    public hourlyRateId: string,
    public hourTimestamp: BigInt,
  ) {}
}

class WeeklyVaultRateResult {
  constructor(
    public weeklyRateId: string,
    public weekTimestamp: BigInt,
  ) {}
}

export function handleVaultRate(block: ethereum.Block, vaultId: string): void {
  const vault = getOrCreateVault(Address.fromString(vaultId), block)
  const hourlyResult = getHourlyVaultRateIdAndTimestamp(block, vaultId)
  const dailyResult = getDailyVaultRateIdAndTimestamp(block, vaultId)
  const weeklyResult = getWeeklyVaultRateIdAndTimestamp(block, vaultId)

  // Update averages
  updateDailyAverage(
    vaultId,
    vault.calculatedApr,
    dailyResult.dayTimestamp,
    dailyResult.dailyRateId,
  )
  updateHourlyAverage(
    vaultId,
    vault.calculatedApr,
    hourlyResult.hourTimestamp,
    hourlyResult.hourlyRateId,
  )
  updateWeeklyAverage(
    vaultId,
    vault.calculatedApr,
    weeklyResult.weekTimestamp,
    weeklyResult.weeklyRateId,
  )
}

export function getDailyVaultRateIdAndTimestamp(
  block: ethereum.Block,
  vaultId: string,
): DailyVaultRateResult {
  const dayTimestamp = getDailyTimestamp(block.timestamp)
  const dailyRateId = vaultId + dayTimestamp.toString()
  return new DailyVaultRateResult(dailyRateId, dayTimestamp)
}

export function getDailyTimestamp(timestamp: BigInt): BigInt {
  return timestamp.div(BigIntConstants.DAY_IN_SECONDS).times(BigIntConstants.DAY_IN_SECONDS)
}

export function getHourlyTimestamp(timestamp: BigInt): BigInt {
  return timestamp.div(BigIntConstants.HOUR_IN_SECONDS).times(BigIntConstants.HOUR_IN_SECONDS)
}

export function getHourlyOffsetTimestamp(timestamp: BigInt): BigInt {
  return timestamp
    .minus(BigIntConstants.HOUR_IN_SECONDS)
    .div(BigIntConstants.HOUR_IN_SECONDS)
    .times(BigIntConstants.HOUR_IN_SECONDS)
}

export function getHourlyVaultRateIdAndTimestamp(
  block: ethereum.Block,
  vaultId: string,
): HourlyVaultRateResult {
  const hourTimestamp = getHourlyOffsetTimestamp(block.timestamp)

  const hourlyRateId = vaultId + hourTimestamp.toString()
  return new HourlyVaultRateResult(hourlyRateId, hourTimestamp)
}

export function getWeeklyOffsetTimestamp(timestamp: BigInt): BigInt {
  const offsetTimestamp = timestamp.plus(BigIntConstants.EPOCH_WEEK_OFFSET)
  const weekTimestamp = offsetTimestamp
    .div(BigIntConstants.WEEK_IN_SECONDS)
    .times(BigIntConstants.WEEK_IN_SECONDS)
    .minus(BigIntConstants.EPOCH_WEEK_OFFSET)
  return weekTimestamp
}

export function getWeeklyVaultRateIdAndTimestamp(
  block: ethereum.Block,
  vaultId: string,
): WeeklyVaultRateResult {
  const weekTimestamp = getWeeklyOffsetTimestamp(block.timestamp)
  const weeklyRateId = vaultId + weekTimestamp.toString()
  return new WeeklyVaultRateResult(weeklyRateId, weekTimestamp)
}

function updateDailyAverage(
  vaultId: string,
  newRate: BigDecimal,
  dayTimestamp: BigInt,
  dailyRateId: string,
): void {
  let dailyRate = DailyInterestRate.load(dailyRateId)
  if (dailyRate === null) {
    dailyRate = new DailyInterestRate(dailyRateId)
    dailyRate.date = dayTimestamp
    dailyRate.sumRates = BigDecimalConstants.ZERO
    dailyRate.updateCount = BigInt.fromI32(0)
    dailyRate.averageRate = BigDecimalConstants.ZERO
    dailyRate.vault = vaultId
  }

  dailyRate.sumRates = dailyRate.sumRates.plus(newRate)
  dailyRate.updateCount = dailyRate.updateCount.plus(BigInt.fromI32(1))
  dailyRate.averageRate = dailyRate.sumRates.div(
    BigDecimal.fromString(dailyRate.updateCount.toString()),
  )

  dailyRate.save()
}

function updateHourlyAverage(
  vaultId: string,
  newRate: BigDecimal,
  hourTimestamp: BigInt,
  hourlyRateId: string,
): void {
  let hourlyRate = HourlyInterestRate.load(hourlyRateId)
  if (hourlyRate === null) {
    hourlyRate = new HourlyInterestRate(hourlyRateId)
    hourlyRate.date = hourTimestamp
    hourlyRate.sumRates = BigDecimalConstants.ZERO
    hourlyRate.updateCount = BigInt.fromI32(0)
    hourlyRate.averageRate = BigDecimalConstants.ZERO
    hourlyRate.vault = vaultId
  }

  hourlyRate.sumRates = hourlyRate.sumRates.plus(newRate)
  hourlyRate.updateCount = hourlyRate.updateCount.plus(BigInt.fromI32(1))

  if (hourlyRate.updateCount.gt(BigInt.fromI32(0))) {
    hourlyRate.averageRate = hourlyRate.sumRates.div(
      BigDecimal.fromString(hourlyRate.updateCount.toString()),
    )
  } else {
    hourlyRate.averageRate = BigDecimalConstants.ZERO
  }

  hourlyRate.save()
}

function updateWeeklyAverage(
  vaultId: string,
  newRate: BigDecimal,
  weekTimestamp: BigInt,
  weeklyRateId: string,
): void {
  let weeklyRate = WeeklyInterestRate.load(weeklyRateId)
  if (weeklyRate === null) {
    weeklyRate = new WeeklyInterestRate(weeklyRateId)
    weeklyRate.date = weekTimestamp
    weeklyRate.sumRates = BigDecimalConstants.ZERO
    weeklyRate.updateCount = BigInt.fromI32(0)
    weeklyRate.averageRate = BigDecimalConstants.ZERO
    weeklyRate.vault = vaultId
  }

  weeklyRate.sumRates = weeklyRate.sumRates.plus(newRate)
  weeklyRate.updateCount = weeklyRate.updateCount.plus(BigInt.fromI32(1))
  weeklyRate.averageRate = weeklyRate.sumRates.div(
    BigDecimal.fromString(weeklyRate.updateCount.toString()),
  )

  weeklyRate.save()
}
