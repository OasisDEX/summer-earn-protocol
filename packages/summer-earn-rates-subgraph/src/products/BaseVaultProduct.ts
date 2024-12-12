import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { VaultState } from '../../generated/schema'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

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
  abstract getSharePrice(): BigDecimal

  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const sharePrice = this.getSharePrice()
    if (sharePrice.equals(BigDecimalConstants.ZERO)) {
      return BigDecimalConstants.ZERO
    }
    // if the share price is the same as the previous share price, return 0
    // this is to prevent division by zero in the calculation,
    // not update the lastSharePrice,lastUpdateTimestamp
    // and to avoid unnecessary calculations
    const previousSharePrice = this.getPreviousSharePrice()
    if (previousSharePrice.equals(sharePrice)) {
      return BigDecimalConstants.ZERO
    }
    const priceChange = sharePrice.minus(previousSharePrice).div(previousSharePrice)
    const timeDiff = this.getTimeDifference(currentTimestamp)
    this.updatePreviousSharePrice(sharePrice, currentTimestamp)

    if (timeDiff.equals(BigInt.zero())) {
      return BigDecimalConstants.ZERO
    }
    const annualizedRate = priceChange
      .times(BigDecimalConstants.SECONDS_PER_YEAR)
      .div(timeDiff.toBigDecimal())
      .times(BigDecimalConstants.HUNDRED)

    return annualizedRate
  }

  private getTimeDifference(currentTimestamp: BigInt): BigInt {
    let vaultState = VaultState.load(this.poolAddress)
    if (!vaultState) {
      return BigInt.zero()
    } else {
      return currentTimestamp.minus(vaultState.lastUpdateTimestamp)
    }
  }

  private getPreviousSharePrice(): BigDecimal {
    let vaultState = VaultState.load(this.poolAddress)
    if (!vaultState || vaultState.lastSharePrice.equals(BigDecimalConstants.ZERO)) {
      return BigDecimalConstants.ONE
    } else {
      return vaultState.lastSharePrice
    }
  }

  private updatePreviousSharePrice(newSharePrice: BigDecimal, currentTimestamp: BigInt): void {
    let vaultState = VaultState.load(this.poolAddress)
    if (!vaultState) {
      vaultState = new VaultState(this.poolAddress)
      vaultState.lastSharePrice = newSharePrice
      vaultState.lastUpdateTimestamp = currentTimestamp
    } else {
      vaultState.lastSharePrice = newSharePrice
      vaultState.lastUpdateTimestamp = currentTimestamp
    }
    vaultState.save()
  }
}
