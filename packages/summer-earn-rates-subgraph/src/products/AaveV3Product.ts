import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { AaveV3PoolDataProvider } from '../../generated/EntryPoint/AaveV3PoolDataProvider'
import { Token } from '../../generated/schema'
import { addresses } from '../constants/addresses'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

export class AaveV3Product extends Product {
  constructor(token: Token, poolAddress: Address, startBlock: BigInt, name: string) {
    super(token, poolAddress, startBlock, name)
  }
  getRate(currentTimestamp: BigInt): BigDecimal {
    const pool = AaveV3PoolDataProvider.bind(addresses.AAVE_DATA_PROVIDER)
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
