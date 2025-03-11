import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { Token } from '../../generated/schema'

export class AuctionDetails {
  auctionId: BigInt
  rewardToken: Token
  buyToken: Token
  startBlock: BigInt
  endBlock: BigInt
  startPrice: BigDecimal
  endPrice: BigDecimal
  tokensLeft: BigInt
  constructor(
    auctionId: BigInt,
    rewardToken: Token,
    buyToken: Token,
    startBlock: BigInt,
    endBlock: BigInt,
    startPrice: BigDecimal,
    endPrice: BigDecimal,
    tokensLeft: BigInt,
  ) {
    this.auctionId = auctionId
    this.rewardToken = rewardToken
    this.buyToken = buyToken
    this.startBlock = startBlock
    this.endBlock = endBlock
    this.startPrice = startPrice
    this.endPrice = endPrice
    this.tokensLeft = tokensLeft
  }
}
