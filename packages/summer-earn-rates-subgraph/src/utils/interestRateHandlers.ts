import { BigDecimal, BigInt, ByteArray, crypto, ethereum } from '@graphprotocol/graph-ts'
import {
  DailyInterestRate,
  HourlyInterestRate,
  InterestRate,
  RewardsInterestRate,
  WeeklyInterestRate,
} from '../../generated/schema'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'

class DailyRateResult {
  constructor(
    public dailyRateId: string,
    public dayTimestamp: BigInt,
  ) {}
}

class HourlyRateResult {
  constructor(
    public hourlyRateId: string,
    public hourTimestamp: BigInt,
  ) {}
}

class WeeklyRateResult {
  constructor(
    public weeklyRateId: string,
    public weekTimestamp: BigInt,
  ) {}
}

export function handleInterestRate(
  block: ethereum.Block,
  protocolName: string,
  product: Product,
  normalizedTimestamp: BigInt,
): void {
  const rate = product.getAPY(block.timestamp, block.number)
  const interestRate = new InterestRate(
    `${protocolName}-${product.token.id.toHexString()}-${block.number.toString()}-${crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString()}`,
  )

  const hourlyResult = getHourlyRateIdAndTimestamp(normalizedTimestamp, protocolName, product)
  const dailyResult = getDailyRateIdAndTimestamp(normalizedTimestamp, protocolName, product)
  const weeklyResult = getWeeklyRateIdAndTimestamp(normalizedTimestamp, protocolName, product)

  interestRate.dailyRateId = dailyResult.dailyRateId
  interestRate.hourlyRateId = hourlyResult.hourlyRateId
  interestRate.weeklyRateId = weeklyResult.weeklyRateId
  interestRate.blockNumber = block.number
  interestRate.rate = rate
  interestRate.timestamp = normalizedTimestamp
  interestRate.type = 'Supply'
  interestRate.protocol = protocolName
  interestRate.token = product.token.id
  interestRate.productId = product.name
  interestRate.product = product.name
  interestRate.save()

  updateDailyAverage(protocolName, product, rate, dailyResult.dayTimestamp, dailyResult.dailyRateId)
  updateHourlyAverage(
    protocolName,
    product,
    rate,
    hourlyResult.hourTimestamp,
    hourlyResult.hourlyRateId,
  )
  updateWeeklyAverage(
    protocolName,
    product,
    rate,
    weeklyResult.weekTimestamp,
    weeklyResult.weeklyRateId,
  )

  const rewardRates = product.getRewardsApys(block.timestamp, block.number)
  for (let i = 0; i < rewardRates.length; i++) {
    const reward = rewardRates[i]
    const rewardRate = new RewardsInterestRate(
      `${protocolName}-${product.token.id.toHexString()}-${block.number.toString()}-${crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString()}-${i.toString()}`,
    )
    rewardRate.blockNumber = block.number
    rewardRate.rate = reward.rate
    rewardRate.timestamp = normalizedTimestamp
    rewardRate.type = 'Supply'
    rewardRate.protocol = protocolName
    rewardRate.token = product.token.id
    rewardRate.productId = product.name
    rewardRate.product = product.name
    rewardRate.rewardToken = reward.rewardToken.id

    rewardRate.save()
  }
}

function getDailyRateIdAndTimestamp(
  normalizedTimestamp: BigInt,
  protocolName: string,
  product: Product,
): DailyRateResult {
  const dayTimestamp = normalizedTimestamp
    .div(BigIntConstants.DAY_IN_SECONDS)
    .times(BigIntConstants.DAY_IN_SECONDS)

  const dailyRateId =
    protocolName +
    product.token.id.toHexString() +
    crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString() +
    dayTimestamp.toString()
  return new DailyRateResult(dailyRateId, dayTimestamp)
}

function getHourlyRateIdAndTimestamp(
  normalizedTimestamp: BigInt,
  protocolName: string,
  product: Product,
): HourlyRateResult {
  const hourTimestamp = normalizedTimestamp
    .div(BigIntConstants.HOUR_IN_SECONDS)
    .times(BigIntConstants.HOUR_IN_SECONDS)

  const hourlyRateId =
    protocolName +
    product.token.id.toHexString() +
    crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString() +
    hourTimestamp.toString()
  return new HourlyRateResult(hourlyRateId, hourTimestamp)
}

function getWeeklyRateIdAndTimestamp(
  normalizedTimestamp: BigInt,
  protocolName: string,
  product: Product,
): WeeklyRateResult {
  const offsetTimestamp = normalizedTimestamp.plus(BigIntConstants.EPOCH_WEEK_OFFSET)
  const weekTimestamp = offsetTimestamp
    .div(BigIntConstants.WEEK_IN_SECONDS)
    .times(BigIntConstants.WEEK_IN_SECONDS)
    .minus(BigIntConstants.EPOCH_WEEK_OFFSET)

  const weeklyRateId =
    protocolName +
    product.token.id.toHexString() +
    crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString() +
    weekTimestamp.toString()
  return new WeeklyRateResult(weeklyRateId, weekTimestamp)
}

function updateDailyAverage(
  protocolName: string,
  product: Product,
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
    dailyRate.protocol = protocolName
    dailyRate.token = product.token.id
    dailyRate.productId = product.name
    dailyRate.product = product.name
  }

  dailyRate.sumRates = dailyRate.sumRates.plus(newRate)
  dailyRate.updateCount = dailyRate.updateCount.plus(BigInt.fromI32(1))
  dailyRate.averageRate = dailyRate.sumRates.div(
    BigDecimal.fromString(dailyRate.updateCount.toString()),
  )

  dailyRate.save()
}

function updateHourlyAverage(
  protocolName: string,
  product: Product,
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
    hourlyRate.protocol = protocolName
    hourlyRate.token = product.token.id
    hourlyRate.productId = product.name
    hourlyRate.product = product.name
  }

  hourlyRate.sumRates = hourlyRate.sumRates.plus(newRate)
  hourlyRate.updateCount = hourlyRate.updateCount.plus(BigInt.fromI32(1))
  hourlyRate.averageRate = hourlyRate.sumRates.div(
    BigDecimal.fromString(hourlyRate.updateCount.toString()),
  )

  hourlyRate.save()
}

function updateWeeklyAverage(
  protocolName: string,
  product: Product,
  newRate: BigDecimal,
  weekTimestamp: BigInt,
  weeklyRateId: string,
): void {
  let weeklyRate = WeeklyInterestRate.load(weeklyRateId)
  if (weeklyRate === null) {
    weeklyRate = new WeeklyInterestRate(weeklyRateId)
    weeklyRate.weekTimestamp = weekTimestamp
    weeklyRate.sumRates = BigDecimalConstants.ZERO
    weeklyRate.updateCount = BigInt.fromI32(0)
    weeklyRate.averageRate = BigDecimalConstants.ZERO
    weeklyRate.protocol = protocolName
    weeklyRate.token = product.token.id
    weeklyRate.productId = product.name
    weeklyRate.product = product.name
  }

  weeklyRate.sumRates = weeklyRate.sumRates.plus(newRate)
  weeklyRate.updateCount = weeklyRate.updateCount.plus(BigInt.fromI32(1))
  weeklyRate.averageRate = weeklyRate.sumRates.div(
    BigDecimal.fromString(weeklyRate.updateCount.toString()),
  )

  weeklyRate.save()
}
