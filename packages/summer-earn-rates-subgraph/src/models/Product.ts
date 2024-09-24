import { Address, BigDecimal, BigInt, Bytes } from '@graphprotocol/graph-ts'
import { Token } from '../../generated/schema';

export class Product {
  token: Token;
  address: Address;
  startBlock: BigInt;
  name: string;

  constructor(token: Token, address: Address, startBlock: BigInt, name: string) {
    this.token = token;
    this.address = address;
    this.startBlock = startBlock;
    this.name = name;
  }

  getRate(currentTimestamp: BigInt): BigDecimal {
    return BigDecimal.zero();
  }
}
