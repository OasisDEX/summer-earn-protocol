import { Product } from '../models/Product'

/**
 * Protocol class representing a DeFi protocol
 *
 * To add a new protocol:
 * 1. Create instances of appropriate Product classes for the protocol
 * 2. Create a new Protocol instance in the ProtocolConfig class (in protocolConfig.ts)
 *
 * Example in protocolConfig.ts:
 *
 * new Protocol('NewProtocol', [
 *   new NewProduct(
 *     getOrCreateToken(addresses.TOKEN_ADDRESS),
 *     Address.fromString('POOL_ADDRESS'),
 *     BigInt.fromI32(START_BLOCK),
 *     'NewProtocol',
 *     Address.fromString('ORACLE_ADDRESS')
 *   ),
 *   // Add more products as needed
 * ])
 */
export class Protocol {
  name: string
  products: Product[]

  constructor(name: string, products: Product[]) {
    this.name = name
    this.products = products
  }
}
