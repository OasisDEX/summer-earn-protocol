import { BigDecimal } from '@graphprotocol/graph-ts'
import { PendleOracle } from '../../generated/EntryPoint/PendleOracle'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { BaseVaultProduct } from './BaseVaultProduct'

export class PendleLpProduct extends BaseVaultProduct {
  getSharePrice(): BigDecimal {
    const pendleOracle = PendleOracle.bind(addresses.PENDLE_ORACLE)
    const maybeRate = pendleOracle.try_getLpToAssetRate(
      this.poolAddress,
      BigIntConstants.THIRTY_MINUTES_IN_SECONDS,
    )
    if (!maybeRate.reverted) {
      return maybeRate.value.toBigDecimal()
    } else {
      return BigDecimalConstants.ZERO
    }
  }
}
