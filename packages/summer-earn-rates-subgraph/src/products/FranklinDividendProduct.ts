import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { VaultState } from '../../generated/schema'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'
import { TvlData } from '../models/TvlData'
import { RewardRate } from './BaseVaultProduct'

/**
 * Franklin Templeton BENJI / iBENJI money-market funds. Yield does not move the fund's NAV
 * (BENJI/iBENJI target a constant ~$1.00 share price); it is instead delivered as a daily
 * dividend rate emitted by FT's TransferAgentModule `DividendDistributed` event. That rate is
 * not readable via any view/storage call, so it can only be captured by the event handler
 * (src/franklinMapping.ts), which persists it on the shared VaultState entity keyed by the
 * TransferAgentModule proxy address (passed here as `oracle`). This class only reads that
 * state; it never calls the chain directly.
 */
export class FranklinDividendProduct extends Product {
  static DAYS_PER_YEAR: BigDecimal = BigDecimal.fromString('365')

  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (this.oracle === null) {
      return BigDecimalConstants.ZERO
    }
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const vaultState = VaultState.load(this.oracle!)
    if (!vaultState || !vaultState.lastRate) {
      return BigDecimalConstants.ZERO
    }
    const lastRate = vaultState.lastRate!
    return lastRate.times(FranklinDividendProduct.DAYS_PER_YEAR).times(BigDecimalConstants.HUNDRED)
  }

  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
  }
}
