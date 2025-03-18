import { Address, BigInt } from '@graphprotocol/graph-ts'
import {
  ArkAuctionParametersSet,
  ArkRewardTokenAuctionStarted,
  AuctionFinalized,
  TokensPurchased,
} from '../../generated/Raft/Raft'
import { TokensPurchased as TokensPurchasedEntity } from '../../generated/schema'
import {
  getOrCreateAccount,
  getOrCreateArkAuctionParameters,
  getOrCreateAuction,
  getOrCreateToken,
  updateArkAuctionParameters,
  updateAuction,
} from '../common/initializers'
import { getTokenPriceInUSD } from '../common/priceHelpers'
import { formatAmount } from '../common/utils'
export function handleArkRewardTokenAuctionStarted(event: ArkRewardTokenAuctionStarted): void {
  const auction = getOrCreateAuction(
    event.params.auctionId,
    event.params.ark,
    event.params.rewardToken,
    event.block.timestamp,
  )
}

export function handleAuctionFinalized(event: AuctionFinalized): void {
  const auction = getOrCreateAuction(event.params.auctionId)
  updateAuction(auction, Address.fromString(auction.ark), Address.fromString(auction.rewardToken))
}

export function handleTokensPurchased(event: TokensPurchased): void {
  const auction = getOrCreateAuction(event.params.auctionId)
  updateAuction(auction, Address.fromString(auction.ark), Address.fromString(auction.rewardToken))
  const tokensPurchased = new TokensPurchasedEntity(
    event.params.auctionId.toString() +
      '-' +
      event.params.buyer.toHexString() +
      '-' +
      event.block.number.toString(),
  )
  tokensPurchased.auction = auction.id
  tokensPurchased.tokensPurchased = event.params.amount
  const buyToken = getOrCreateToken(Address.fromString(auction.buyToken))
  const rewardToken = getOrCreateToken(Address.fromString(auction.rewardToken))
  const buyer = getOrCreateAccount(event.params.buyer.toHexString())
  tokensPurchased.buyer = buyer.id
  tokensPurchased.tokensPurchasedNormalized = formatAmount(
    event.params.amount,
    BigInt.fromI32(rewardToken.decimals),
  )
  tokensPurchased.pricePerToken = event.params.price
  tokensPurchased.pricePerTokenNormalized = formatAmount(
    event.params.price,
    BigInt.fromI32(buyToken.decimals),
  )
  tokensPurchased.totalCost = event.params.price
    .times(event.params.amount)
    .div(BigInt.fromI32(rewardToken.decimals))
  tokensPurchased.totalCostNormalized = tokensPurchased.pricePerTokenNormalized.times(
    tokensPurchased.tokensPurchasedNormalized,
  )

  const marketPrice = getTokenPriceInUSD(Address.fromString(auction.buyToken), event.block)
  tokensPurchased.marketPriceInUSDNormalized = marketPrice.price

  tokensPurchased.timestamp = event.block.timestamp
  tokensPurchased.save()
}

export function handleArkAuctionParametersSet(event: ArkAuctionParametersSet): void {
  const arkAuctionParameters = getOrCreateArkAuctionParameters(
    event.params.ark,
    event.params.rewardToken,
  )
  updateArkAuctionParameters(event.params.ark, event.params.rewardToken, arkAuctionParameters)
}
