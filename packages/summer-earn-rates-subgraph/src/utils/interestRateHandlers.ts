import { BigDecimal, BigInt, ByteArray, crypto, ethereum } from '@graphprotocol/graph-ts'
import { DailyInterestRate, HourlyInterestRate, InterestRate } from '../../generated/schema'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

export function handleInterestRate(
  block: ethereum.Block,
  protocolName: string,
  product: Product,
): void {
  const rate = product.getRate(block.timestamp, block.number)
  const interestRate = new InterestRate(
    protocolName +
      product.token.id.toHexString() +
      block.number.toString() +
      crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString(),
  )
  const dayTimestamp = block.timestamp.div(BigInt.fromI32(86400)).times(BigInt.fromI32(86400))

  const dailyRateId =
    protocolName +
    product.token.id.toHexString() +
    crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString() +
    dayTimestamp.toString()

  const hourTimestamp = block.timestamp.div(BigInt.fromI32(3600)).times(BigInt.fromI32(3600))

  const hourlyRateId =
    protocolName +
    product.token.id.toHexString() +
    crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString() +
    hourTimestamp.toString()

  interestRate.dailyRateId = dailyRateId
  interestRate.hourlyRateId = hourlyRateId
  interestRate.blockNumber = block.number
  interestRate.rate = rate
  interestRate.timestamp = block.timestamp
  interestRate.type = 'Supply'
  interestRate.protocol = protocolName
  interestRate.token = product.token.id
  interestRate.productId = product.name
  interestRate.save()

  updateDailyAverage(block, protocolName, product, rate, dayTimestamp, dailyRateId)
  updateHourlyAverage(block, protocolName, product, rate, hourTimestamp, hourlyRateId)
}
function updateDailyAverage(
  block: ethereum.Block,
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
  }

  dailyRate.sumRates = dailyRate.sumRates.plus(newRate)
  dailyRate.updateCount = dailyRate.updateCount.plus(BigInt.fromI32(1))
  dailyRate.averageRate = dailyRate.sumRates.div(
    BigDecimal.fromString(dailyRate.updateCount.toString()),
  )

  dailyRate.save()
}

function updateHourlyAverage(
  block: ethereum.Block,
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
  }

  hourlyRate.sumRates = hourlyRate.sumRates.plus(newRate)
  hourlyRate.updateCount = hourlyRate.updateCount.plus(BigInt.fromI32(1))
  hourlyRate.averageRate = hourlyRate.sumRates.div(
    BigDecimal.fromString(hourlyRate.updateCount.toString()),
  )

  hourlyRate.save()
}
