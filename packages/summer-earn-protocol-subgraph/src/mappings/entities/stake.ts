import { BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { Staked } from '../../../generated/schema'
import { Staked as StakedEvent } from '../../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import { PositionDetails } from '../../types'

export function createStakedEventEntity(
  event: StakedEvent,
  amount: BigInt,
  normalizedAmountUSD: BigDecimal,
  positionDetails: PositionDetails,
): void {
  const staked = new Staked(`${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`)
  staked.amount = amount
  staked.amountUSD = normalizedAmountUSD
  staked.from = positionDetails.account
  staked.to = positionDetails.vault
  staked.blockNumber = event.block.number
  staked.timestamp = event.block.timestamp
  staked.vault = positionDetails.vault
  staked.asset = positionDetails.inputToken.id
  staked.protocol = positionDetails.protocol
  staked.logIndex = event.logIndex.toI32()
  staked.hash = event.transaction.hash.toHexString()
  staked.position = positionDetails.positionId
  staked.inputTokenBalance = positionDetails.inputTokenBalance
  staked.inputTokenBalanceNormalizedUSD = positionDetails.inputTokenBalanceNormalizedUSD
  staked.save()
}
