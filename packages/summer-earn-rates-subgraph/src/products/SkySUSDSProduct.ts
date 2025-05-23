import { Address, BigDecimal, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { ERC4626 } from '../../generated/EntryPoint/ERC4626'
import { SkyPSM3 } from '../../generated/EntryPoint/SkyPSM3'
import { SkySSRAuthOracle } from '../../generated/EntryPoint/SkySSRAuthOracle'
import { SkySUSDS } from '../../generated/EntryPoint/SkySUSDS'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'
import { TvlData } from '../models/TvlData'
import { formatAmount } from '../utils/formatters'
import { getOrCreateToken } from '../utils/initializers'
import { getTokenPriceInUSD } from '../utils/price-helper'
import { RewardRate } from './BaseVaultProduct'

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

  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }

  getTvl(currentTimestamp: BigInt, currentBlock: BigInt): TvlData {
    const vault = ERC4626.bind(addresses.SUSDS)
    const tryTotalAssets = vault.try_totalAssets()
    const tryAsset = vault.try_asset()

    if (tryTotalAssets.reverted || tryAsset.reverted) {
      return new TvlData(BigIntConstants.ZERO, BigDecimalConstants.ZERO, BigDecimalConstants.ZERO)
    }

    const asset = getOrCreateToken(tryAsset.value)
    const tokenAmountRaw = tryTotalAssets.value
    const tokenAmountNormalized = formatAmount(tokenAmountRaw, asset.decimals)
    const tokenPriceInUsd = getTokenPriceInUSD(Address.fromBytes(asset.address), currentBlock)
    const usdAmountNormalized = tokenAmountNormalized.times(tokenPriceInUsd.price)

    return new TvlData(tokenAmountRaw, tokenAmountNormalized, usdAmountNormalized)
  }
}
