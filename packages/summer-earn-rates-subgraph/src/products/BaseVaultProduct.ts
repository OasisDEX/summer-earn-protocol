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
    if (timeDiff.equals(BigInt.zero())) {
      return previousRate
    }
    const annualizedRate = priceChange
      .times(BigDecimalConstants.SECONDS_PER_YEAR)
      .div(timeDiff.toBigDecimal())
      .times(BigDecimalConstants.HUNDRED)
    const annualizedRateBelowZero = annualizedRate.lt(BigDecimalConstants.ZERO)
    const annualizedRateBelowThreshold = annualizedRate.lt(this.threshold)
    // if the rate is below zero - it's most likely vault taking a fee
    // we return the previous rate as it's more likely to be correct
    // and we don't want to report negative rates
    // we update vault state to have a correct start point for next update calculation
    if (annualizedRateBelowZero) {
      this.updateVaultState(sharePrice, annualizedRate, currentTimestamp, vaultState)
      return previousRate
    }
    // if the rate is above zero but below threshold - we want to keep displaying the same rate
    // as it's most likely vault state change due to deposit/withdrawals
    // we don't update the vault state in this case, to have a correct starting point for next update calculation (for timeDiff)
    if (annualizedRateBelowThreshold) {
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
