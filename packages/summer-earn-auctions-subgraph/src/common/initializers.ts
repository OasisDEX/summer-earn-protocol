import { Address, BigInt } from '@graphprotocol/graph-ts'
import { ERC20 as ERC20Contract } from '../../generated/HarborCommand/ERC20'
import { Ark as ArkContract } from '../../generated/Raft/Ark'
import { Raft as RaftContract } from '../../generated/Raft/Raft'
import { Account, Ark, ArkAuctionParameters, Auction, Token } from '../../generated/schema'
import { addresses } from './addressProvider'
import * as constants from './constants'
import { BigDecimalConstants } from './constants'
import * as utils from './utils'
import { formatAmount } from './utils'

export function getOrCreateAuction(
  auctionId: BigInt,
  raft: Address,
  ark: Address = Address.zero(),
  rewardToken: Address = Address.zero(),
  startTimestamp: BigInt = BigInt.fromI32(0),
): Auction {
  let auction = Auction.load(raft.toHexString() + '-' + auctionId.toString())
  if (!auction && ark != Address.zero() && rewardToken != Address.zero()) {
    auction = new Auction(raft.toHexString() + '-' + auctionId.toString())
    auction.startTimestamp = startTimestamp
    auction.raft = raft.toHexString()
    updateAuction(auction, ark, rewardToken)
  }
  return auction!
}

export function updateAuction(auction: Auction, ark: Address, rewardToken: Address): void {
  const autionParams = getOrCreateArkAuctionParameters(
    ark,
    rewardToken,
    Address.fromString(auction.raft),
  )

  const raftContract = RaftContract.bind(Address.fromString(auction.raft))
  const auctionState = raftContract.try_auctions(ark, rewardToken)
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
  raft: Address,
): ArkAuctionParameters {
  const arkAuctionParametersId = getArkAuctionParametersId(raft, ark, rewardToken)
  let arkAuctionParameters = ArkAuctionParameters.load(arkAuctionParametersId)
  if (!arkAuctionParameters) {
    arkAuctionParameters = new ArkAuctionParameters(arkAuctionParametersId)
    updateArkAuctionParameters(ark, rewardToken, raft, arkAuctionParameters)
  }
  return arkAuctionParameters
}

export function updateArkAuctionParameters(
  ark: Address,
  rewardToken: Address,
  raft: Address,
  arkAuctionParameters: ArkAuctionParameters,
): void {
  const arkContract = ArkContract.bind(ark)
  const buyToken = arkContract.try_asset()
  const raftContract = RaftContract.bind(raft)
  const params = raftContract.try_arkAuctionParameters(ark, rewardToken)
  const rewardTokenEntity = getOrCreateToken(rewardToken)
  const buyTokenEntity = getOrCreateToken(buyToken.value)

  arkAuctionParameters.ark = getOrCreateArk(ark).id
  arkAuctionParameters.rewardToken = rewardTokenEntity.id
  arkAuctionParameters.buyToken = buyTokenEntity.id
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

function getArkAuctionParametersId(raft: Address, ark: Address, rewardToken: Address): string {
  return raft.toHexString() + ark.toHexString() + rewardToken.toHexString()
}
