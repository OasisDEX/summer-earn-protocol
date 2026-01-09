import { BigInt } from '@graphprotocol/graph-ts'

export class TransferabilityEnabledBlockByChain {
  static ARBITRUM_ONE: BigInt = BigInt.fromI32(375205371)
  static MAINNET: BigInt = BigInt.fromI32(23281546)
  static SONIC_MAINNET: BigInt = BigInt.fromI32(45585548)
  static BASE: BigInt = BigInt.fromI32(35006901)
  static HYPERLIQUID: BigInt = BigInt.fromI32(0)
}

export function getTransferabilityEnabledBlockByChain(chain: string): BigInt {
  if (chain == 'arbitrum-one') {
    return TransferabilityEnabledBlockByChain.ARBITRUM_ONE
  } else if (chain == 'mainnet') {
    return TransferabilityEnabledBlockByChain.MAINNET
  } else if (chain == 'sonic-mainnet') {
    return TransferabilityEnabledBlockByChain.SONIC_MAINNET
  } else if (chain == 'base') {
    return TransferabilityEnabledBlockByChain.BASE
  } else if (chain == 'hyperliquid' || chain == 'hyperevm') {
    return TransferabilityEnabledBlockByChain.HYPERLIQUID
  } else {
    throw new Error(`Unsupported chain: ${chain}`)
  }
}
