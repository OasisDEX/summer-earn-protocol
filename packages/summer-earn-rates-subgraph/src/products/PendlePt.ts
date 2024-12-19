import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { PendleMarket } from '../../generated/EntryPoint/PendleMarket'
import { PendleOracle } from '../../generated/EntryPoint/PendleOracle'
import { Token } from '../../generated/schema'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'

export class PendlePtProduct extends Product {
  marketExpiry: BigInt

  constructor(token: Token, poolAddress: Address, startBlock: BigInt, name: string) {
    super(token, poolAddress, startBlock, name)
    const market = PendleMarket.bind(this.poolAddress)
    const expiry = market.expiry()
    this.marketExpiry = expiry
  }
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    // Get the current exchange rate from PT to inputToken asset (WAD)
    const exchangeRate = this._fetchArkTokenToAssetRate()
    if (exchangeRate.isZero()) return BigDecimalConstants.ZERO

    // Get the time remaining until expiry
    const timeToExpiry = this.marketExpiry.minus(currentTimestamp)
    if (timeToExpiry.isZero()) return BigDecimalConstants.ZERO // Return 0 if market has expired

    // Calculate the implied yield
    const impliedYield = BigIntConstants.RAY.times(BigIntConstants.WAD)
      .div(exchangeRate)
      .minus(BigIntConstants.RAY)

    // Convert implied yield to APR
    const apr = impliedYield.times(BigIntConstants.YEAR_IN_SECONDS).div(timeToExpiry)

    return BigDecimal.fromString(apr.toString())
      .div(BigDecimalConstants.RAY)
      .times(BigDecimalConstants.HUNDRED)
  }

  // Placeholder for the method to fetch the exchange rate
  private _fetchArkTokenToAssetRate(): BigInt {
    const pendleOracle = PendleOracle.bind(addresses.PENDLE_ORACLE)
    const maybeRate = pendleOracle.try_getPtToAssetRate(
      this.poolAddress,
      BigIntConstants.THIRTY_MINUTES_IN_SECONDS,
    )
    if (!maybeRate.reverted) {
      return maybeRate.value
    } else {
      return BigIntConstants.ZERO
    }
  }
}
