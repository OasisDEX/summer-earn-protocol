import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'

/**
 * TvlData is a class that contains the data for the tvl of a product.
 */
export class TvlData {
  constructor(
    public readonly tokenAmountRaw: BigInt,
    public readonly tokenAmountNormalized: BigDecimal,
    public readonly usdAmountNormalized: BigDecimal,
  ) {}
}
