import { ethereum } from '@graphprotocol/graph-ts'
import { Staked } from '../../../generated/schema'
import { PositionDetails } from '../../types'

export function createStakedEventEntity(
  event: ethereum.Event,
  positionDetails: PositionDetails,
): void {
  const staked = new Staked(`${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`)
  staked.amount = positionDetails.stakedInputTokenDelta
  staked.amountUSD = positionDetails.stakedInputTokenDeltaNormalizedUSD
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
