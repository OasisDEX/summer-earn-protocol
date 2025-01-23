import { BigDecimal, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { SkyPSM3 } from '../../generated/EntryPoint/SkyPSM3'
import { SkySSRAuthOracle } from '../../generated/EntryPoint/SkySSRAuthOracle'
import { SkySUSDS } from '../../generated/EntryPoint/SkySUSDS'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'

export class SkySUSDSProduct extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }

    // For L2 networks (non-mainnet)
    if (dataSource.network() != 'mainnet') {
      // Get the rate provider address from PSM3 contract
      const psm3 = SkyPSM3.bind(addresses.SKY_USDS_PSM3)
      const rateProvider = psm3.rateProvider()
      // Connect to the auth oracle which provides APR directly
      const authOracle = SkySSRAuthOracle.bind(rateProvider)
      const apr = authOracle.getAPR()

      // Convert APR from ray format (27 decimals) to percentage
      return apr.toBigDecimal().times(BigDecimalConstants.HUNDRED).div(BigDecimalConstants.RAY)
    }
    // For mainnet
    else {
      // Get the SSR (Steady State Rate) which is a per-second rate
      const susds = SkySUSDS.bind(addresses.SUSDS)
      const ssr = susds.ssr()

      // Convert SSR to APR:
      // 1. Subtract 1 from SSR (as SSR includes the principal)
      // 2. Convert to decimal and normalize from ray format
      // 3. Multiply by seconds per year to get yearly rate
      // 4. Convert to percentage
      const apr = ssr
        .minus(BigIntConstants.RAY)
        .toBigDecimal()
        .div(BigDecimalConstants.RAY)
        .times(BigDecimalConstants.SECONDS_PER_YEAR)
      return apr.times(BigDecimalConstants.HUNDRED)
    }
  }
}
