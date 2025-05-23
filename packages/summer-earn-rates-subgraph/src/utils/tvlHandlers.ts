import { BigInt, ByteArray, crypto, ethereum } from '@graphprotocol/graph-ts'
import { TotalValueLocked } from '../../generated/schema'
import { Product } from '../models/Product'

export function handleTvl(
  block: ethereum.Block,
  protocolName: string,
  product: Product,
  normalizedTimestamp: BigInt,
): void {
  const tvl = product.getTvl(block.timestamp, block.number)
  const totalValueLocked = new TotalValueLocked(
    `${protocolName}-${product.token.id.toHexString()}-${block.number.toString()}-${crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString()}`,
  )
  totalValueLocked.protocol = protocolName
  totalValueLocked.token = product.token.id
  totalValueLocked.productId = product.name
  totalValueLocked.product = product.name
  totalValueLocked.totalValueLockedInAssets = tvl.tokenAmountRaw
  totalValueLocked.totalValueLockedInAssetsNormalized = tvl.tokenAmountNormalized
  totalValueLocked.totalValueLockedInUSD = tvl.usdAmountNormalized
  totalValueLocked.blockNumber = block.number
  totalValueLocked.timestamp = normalizedTimestamp
  totalValueLocked.save()
}
