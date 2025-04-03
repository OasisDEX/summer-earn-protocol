import { Address, BigInt } from '@graphprotocol/graph-ts'
import { ERC20 as ERC20Contract } from '../../generated/HarborCommand/ERC20'
import { Ark as ArkContract } from '../../generated/Raft/Ark'
import { Account, Ark, ArkAuctionParameters, Auction, Token } from '../../generated/schema'
import { addresses, services } from './addressProvider'
import * as constants from './constants'
import { BigDecimalConstants } from './constants'
import * as utils from './utils'
import { formatAmount } from './utils'

export function getOrCreateAuction(
  auctionId: BigInt,
  ark: Address = Address.zero(),
  rewardToken: Address = Address.zero(),
  startTimestamp: BigInt = BigInt.fromI32(0),
): Auction {
  let auction = Auction.load(auctionId.toString())
  if (!auction && ark != Address.zero() && rewardToken != Address.zero()) {
    auction = new Auction(auctionId.toString())
    auction.startTimestamp = startTimestamp
    updateAuction(auction, ark, rewardToken)
  }
  return auction!
}

export function updateAuction(auction: Auction, ark: Address, rewardToken: Address): void {
  const autionParams = getOrCreateArkAuctionParameters(ark, rewardToken)
  const auctionState = services.raft.try_auctions(ark, rewardToken)
  const state = auctionState.value.getState()

  const rewardTokenEntity = getOrCreateToken(rewardToken)
  auction.ark = getOrCreateArk(ark).id
  auction.rewardToken = rewardTokenEntity.id
  const buyTokenEntity = getOrCreateToken(Address.fromString(autionParams.buyToken))
  auction.buyToken = buyTokenEntity.id
  auction.auctionId = auction.id
  auction.startBlock = BigInt.fromI32(0)
  auction.endBlock = null

  auction.endTimestamp = auction.startTimestamp.plus(autionParams.duration)

  auction.startPrice = autionParams.startPrice
  auction.endPrice = autionParams.endPrice
  auction.tokensLeft = state.remainingTokens
  auction.tokensLeftNormalized = formatAmount(
    state.remainingTokens,
    BigInt.fromI32(rewardTokenEntity.decimals),
  )
  auction.kickerRewardPercentage = autionParams.kickerRewardPercentage
  auction.decayType = autionParams.decayType
  auction.duration = autionParams.duration
  auction.isFinalized = state.isFinalized
  auction.save()
}

export function getOrCreateAccount(id: string): Account {
  let account = Account.load(id)

  if (!account) {
    account = new Account(id)
    account.address = id
    account.save()
  }

  return account
}

export function getOrCreateToken(address: Address): Token {
  let token = Token.load(address.toHexString())

  if (!token) {
    token = new Token(address.toHexString())

    const contract = ERC20Contract.bind(address)

    token.name = utils.readValue<string>(contract.try_name(), '')
    if (address == addresses.USDCE) {
      token.symbol = 'USDC.E'
    } else {
      token.symbol = utils.readValue<string>(contract.try_symbol(), '')
    }
    token.decimals = utils
      .readValue<BigInt>(contract.try_decimals(), constants.BigIntConstants.ZERO)
      .toI32() as u8

    token.save()
  }

  return token
}

export function getOrCreateArk(address: Address): Ark {
  let ark = Ark.load(address.toHexString())
  if (!ark) {
    ark = new Ark(address.toHexString())
    ark.address = address.toHexString()
    ark.commander = address.toHexString()
    ark.save()
  }
  return ark
}

export function getOrCreateArkAuctionParameters(
  ark: Address,
  rewardToken: Address,
): ArkAuctionParameters {
  const arkAuctionParametersId = ark.toHexString() + rewardToken.toHexString()
  let arkAuctionParameters = ArkAuctionParameters.load(arkAuctionParametersId)
  if (!arkAuctionParameters) {
    arkAuctionParameters = new ArkAuctionParameters(arkAuctionParametersId)
    updateArkAuctionParameters(ark, rewardToken, arkAuctionParameters)
  }
  return arkAuctionParameters
}

export function updateArkAuctionParameters(
  ark: Address,
  rewardToken: Address,
  arkAuctionParameters: ArkAuctionParameters,
): void {
  const arkContract = ArkContract.bind(ark)
  const buyToken = arkContract.try_asset()

  arkAuctionParameters = new ArkAuctionParameters(ark.toHexString() + rewardToken.toHexString())
  arkAuctionParameters.ark = getOrCreateArk(ark).id
  const rewardTokenEntity = getOrCreateToken(rewardToken)
  arkAuctionParameters.rewardToken = rewardTokenEntity.id
  const buyTokenEntity = getOrCreateToken(buyToken.value)
  arkAuctionParameters.buyToken = buyTokenEntity.id
  const params = services.raft.try_arkAuctionParameters(ark, rewardToken)
  arkAuctionParameters.kickerRewardPercentage = params.value
    .getKickerRewardPercentage()
    .toBigDecimal()
    .div(BigDecimalConstants.WAD)
  arkAuctionParameters.decayType = params.value.getDecayType() == 0 ? 'LINEAR' : 'EXPONENTIAL'
  arkAuctionParameters.duration = params.value.getDuration()
  arkAuctionParameters.startPrice = utils.formatAmount(
    params.value.getStartPrice(),
    BigInt.fromI32(buyTokenEntity.decimals),
  )
  arkAuctionParameters.endPrice = utils.formatAmount(
    params.value.getEndPrice(),
    BigInt.fromI32(buyTokenEntity.decimals),
  )
  arkAuctionParameters.save()
}
