import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { Token, VaultState } from '../../generated/schema'
import { BigDecimalConstants, BigIntConstants } from '../constants/common'
import { Product } from '../models/Product'

export class RewardRate {
  rewardToken: Token
  rate: BigDecimal

  constructor(rewardToken: Token, rate: BigDecimal) {
    this.rewardToken = rewardToken
    this.rate = rate
  }
}

/**
 * @class BaseVaultProduct
 * @extends Product
 *
 * @description
 * The BaseVaultProduct class is an abstract class that extends the Product class. It provides a
 * common interface for fetching the share price of a vault and calculating the rate based on the
 * share price.
 *
 * Usage:
 * - In `ERC4626Product.ts`, the BaseVaultProduct can be utilized to calculate the share price of
 *   the Principal Token when interacting with ERC4626 compliant vaults.
 * - In `GenericVault.ts`, it can be used to provide a generic interface for fetching the share
 *   price of the wrapped asset, allowing for flexibility in handling different vault types.
 * - In `PendleLp.ts`, the BaseVaultProduct can be integrated to fetch the share price of the
 *   Principal Token in the context of liquidity pools, enabling us to calculate the rate of
 *   return for the Pendle LPs.
 */
export abstract class BaseVaultProduct extends Product {
  threshold: BigDecimal = BigDecimalConstants.ONE_BPS
  abstract getSharePrice(): BigDecimal

  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (
      currentBlock.ge(BigInt.fromI32(396229273)) &&
      this.name ==
        'Silo-0xaf88d065e77c8cc2239327c5edb3a432268e5831-0x2433d6ac11193b4695d9ca73530de93c538ad18a-42161'
    ) {
      return BigDecimalConstants.ZERO
    }
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const sharePrice = this.getSharePrice()
    if (sharePrice.equals(BigDecimalConstants.ZERO)) {
      return BigDecimalConstants.ZERO
    }
    const vaultState = this.getOrCreateVaultState()
    // if the share price is the same as the previous share price, return 0
    // this is to prevent division by zero in the calculation,
    // not update the lastSharePrice,lastUpdateTimestamp
    // and to avoid unnecessary calculations
    const previousSharePrice = vaultState.lastSharePrice
    const previousRate = vaultState.lastRate!
    if (previousSharePrice.equals(sharePrice)) {
      return previousRate
    }
    const priceChange = sharePrice.minus(previousSharePrice).div(previousSharePrice)
    const timeDiff = this.getTimeDifference(currentTimestamp, vaultState)
    if (timeDiff.equals(BigIntConstants.ZERO)) {
      return previousRate
    }
    if (
      this.name.toLowerCase().includes('0xa0d3707c569ff8c87fa923d3823ec5d81c98be78') &&
      timeDiff.lt(BigIntConstants.DAY_IN_SECONDS)
    ) {
      return previousRate
    }

    const annualizedRate = priceChange
      .times(BigDecimalConstants.SECONDS_PER_YEAR)
      .div(timeDiff.toBigDecimal())
      .times(BigDecimalConstants.HUNDRED)
    const annualizedRateBelowZero = annualizedRate.lt(this.threshold.neg())
    const annualizedRateWithinThreshold =
      annualizedRate.lt(this.threshold) && annualizedRate.gt(this.threshold.neg())
    // If the rate is negative (e.g., due to a vault fee or loss), we skip updating the vault state and return the previous rate.
    // This means the next time a positive rate is observed, it will be annualized over the entire period since the last update,
    // effectively skipping negative rates and waiting for a positive period before updating the vault state.

    if (annualizedRateBelowZero) {
      // @dev special handling for fluid lite
      // for non fluid lite it's usualy one update with negative rate, so we need to restart accounting from current share price
      // for others it's a longer period of negative rates, hence we air for positive rate to average it out
      if (!this.name.toLowerCase().includes('0xa0d3707c569ff8c87fa923d3823ec5d81c98be78')) {
        this.updateVaultState(sharePrice, annualizedRate, currentTimestamp, vaultState)
      }
      return previousRate
    }
    // If the rate change is minimal (within our threshold), we maintain the previous rate
    // This filters out small fluctuations from routine vault operations like deposits/withdrawals
    // We skip updating vault state to ensure the next calculation uses the original timestamp
    if (
      annualizedRateWithinThreshold &&
      vaultState.lastUpdateTimestamp.notEqual(BigInt.fromI32(0))
    ) {
      return previousRate
    }

    this.updateVaultState(sharePrice, annualizedRate, currentTimestamp, vaultState)

    return annualizedRate
  }
  getRewardsRates(currentTimestamp: BigInt, currentBlock: BigInt): RewardRate[] {
    return []
  }

  private getTimeDifference(currentTimestamp: BigInt, vaultState: VaultState): BigInt {
    return currentTimestamp.minus(vaultState.lastUpdateTimestamp)
  }

  private getOrCreateVaultState(): VaultState {
    let vaultState = VaultState.load(this.poolAddress)
    if (!vaultState) {
      vaultState = new VaultState(this.poolAddress)
      vaultState.lastSharePrice = BigDecimalConstants.ONE
      vaultState.lastRate = BigDecimalConstants.ZERO
      vaultState.lastUpdateTimestamp = BigIntConstants.ZERO
    }
    if (!vaultState.lastRate) {
      vaultState.lastRate = BigDecimalConstants.ZERO
    }
    return vaultState
  }

  private updateVaultState(
    newSharePrice: BigDecimal,
    newRate: BigDecimal,
    currentTimestamp: BigInt,
    vaultState: VaultState,
  ): void {
    vaultState.lastSharePrice = newSharePrice
    vaultState.lastRate = newRate
    vaultState.lastUpdateTimestamp = currentTimestamp
    vaultState.save()
  }
}
