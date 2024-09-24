import { Address, BigDecimal, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { Token } from '../../generated/schema'
import { getChainIdByNetworkName } from '../utils/chainId'

export class Product {
  token: Token
  poolAddress: Address
  startBlock: BigInt
  name: string
  oracle: Address | null

  constructor(
    token: Token,
    poolAddress: Address,
    startBlock: BigInt,
    groupName: string,
    oracle: Address | null = null,
  ) {
    this.token = token
    this.poolAddress = poolAddress
    this.startBlock = startBlock
    this.oracle = oracle
    this.name = `${groupName}-${token.address.toHexString()}-${poolAddress.toHexString()}-${getChainIdByNetworkName(dataSource.network()).toString()}`
  }
  getRate(currentTimestamp: BigInt): BigDecimal {
    return BigDecimal.zero()
  }
}
