import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { EACAggregatorProxy } from '../../generated/EntryPoint/EACAggregatorProxy'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { TvlData } from '../models/TvlData'
import { BaseVaultProduct } from './BaseVaultProduct'

/**
 * Securitize RWA fund priced by its NAV feed (RedStone *_FUNDAMENTAL, exposed as a
 * Chainlink AggregatorV3). The feed answer is the per-share NAV; BaseVaultProduct derives
 * the APR from how that NAV moves over time. Use for funds whose yield shows up as a rising
 * NAV (e.g. ACRED, STAC). The feed decimals cancel out in the share-price ratio, so the raw
 * answer is used directly as the share price.
 */
export class SecuritizePriceFeedProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    if (this.oracle === null) {
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
    return answer.toBigDecimal()
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
  }
}
