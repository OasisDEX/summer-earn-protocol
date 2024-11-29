import { Address, BigDecimal, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { Token } from '../../generated/schema'
import { getChainIdByNetworkName } from '../utils/chainId'

/**
 * Base Product class
 *
 * To add a new product type:
 * 1. Create a new class that extends Product in a new file under the 'products' directory
 * 2. Implement the constructor, passing necessary parameters to super()
 * 3. Override the getRate method to implement product-specific rate calculation logic
 *
 * Example:
 *
 * export class NewProduct extends Product {
 *   constructor(
 *     token: Token,
 *     poolAddress: Address,
 *     startBlock: BigInt,
 *     groupName: string,
 *     oracle: Address | null = null,
 *   ) {
 *     super(token, poolAddress, startBlock, groupName, oracle)
 *   }
 *
 *   getRate(currentTimestamp: BigInt): BigDecimal {
 *     // Implement product-specific rate calculation logic here
 *   }
 * }
 */
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
    this.name = `${groupName}-${token.address.toHexString()}-${poolAddress.toHexString()}-${getChainIdByNetworkName(dataSource.network()).toString().split('.')[0]}`
  }
  getRate(currentTimestamp: BigInt, currentBlock: BigInt): BigDecimal {
    return BigDecimal.zero()
  }
}
