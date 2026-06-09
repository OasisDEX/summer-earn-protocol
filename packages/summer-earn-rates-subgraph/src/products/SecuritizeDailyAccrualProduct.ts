import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { EACAggregatorProxy } from '../../generated/EntryPoint/EACAggregatorProxy'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'
import { TvlData } from '../models/TvlData'
import { RewardRate } from './BaseVaultProduct'

/**
 * Securitize RWA fund priced by its daily-accrual feed (RedStone *_DAILY_ACCRUAL, exposed as a
 * Chainlink AggregatorV3). The feed answer is the per-day yield as a fraction in the feed's
 * decimals (e.g. 9400 at 8 decimals = 0.0094%/day). The APR is that daily fraction annualized
 * linearly (x365); Product.getAPY() then applies the protocol's standard APR->APY conversion.
 * Use for funds whose yield does not move the NAV (e.g. VBILL, held at a $1.00 par price).
 */
export class SecuritizeDailyAccrualProduct extends Product {
  static DAYS_PER_YEAR: BigDecimal = BigDecimal.fromString('365')

  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (this.oracle === null) {
      return BigDecimalConstants.ZERO
    }
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const feed = EACAggregatorProxy.bind(this.oracle!)
    const result = feed.try_latestRoundData()
    if (result.reverted) {
      return BigDecimalConstants.ZERO
    }
    const answer = result.value.value1
    if (answer.le(BigIntConstants.ZERO)) {
      return BigDecimalConstants.ZERO
    }
    const decimalsResult = feed.try_decimals()
    if (decimalsResult.reverted) {
      return BigDecimalConstants.ZERO
    }

    const dailyFraction = answer.toBigDecimal().div(this.pow10(decimalsResult.value))
    return dailyFraction
      .times(SecuritizeDailyAccrualProduct.DAYS_PER_YEAR)
      .times(BigDecimalConstants.HUNDRED)
  }

  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
  }

  private pow10(exponent: i32): BigDecimal {
    let result = BigDecimalConstants.ONE
    const ten = BigDecimal.fromString('10')
    for (let i = 0; i < exponent; i++) {
      result = result.times(ten)
    }
    return result
  }
}
