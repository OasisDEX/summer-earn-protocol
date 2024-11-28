import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { AaveV3PoolDataProvider } from '../../generated/EntryPoint/AaveV3PoolDataProvider'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

export class AaveV3Product extends Product {
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    if (currentBlock.lt(this.startBlock)) {
      return BigDecimalConstants.ZERO
    }
    const pool = AaveV3PoolDataProvider.bind(addresses.AAVE_V3_DATA_PROVIDER)
    const tryReserveData = pool.try_getReserveData(Address.fromBytes(this.token.address))
    if (tryReserveData.reverted) {
      return BigDecimal.zero()
    }
    return tryReserveData.value
      .getLiquidityRate()
      .toBigDecimal()
      .times(BigDecimalConstants.HUNDRED)
      .div(BigDecimalConstants.RAY)
  }
}
