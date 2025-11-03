import { ethereum } from '@graphprotocol/graph-ts'
import { Unstaked } from '../../../generated/schema'
import { PositionDetails } from '../../types'

export function createUnstakedEventEntity(
  event: ethereum.Event,
  positionDetails: PositionDetails,
): void {
  const unstake = new Unstaked(
    `${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`,
  )
  unstake.amount = positionDetails.stakedInputTokenDelta
  unstake.amountUSD = positionDetails.stakedInputTokenDeltaNormalizedUSD
  unstake.from = positionDetails.account
  unstake.to = positionDetails.vault
  unstake.blockNumber = event.block.number
  unstake.timestamp = event.block.timestamp
  unstake.vault = positionDetails.vault
  unstake.asset = positionDetails.inputToken.id
  unstake.protocol = positionDetails.protocol
  unstake.logIndex = event.logIndex.toI32()
  unstake.hash = event.transaction.hash.toHexString()
  unstake.position = positionDetails.positionId
  unstake.inputTokenBalance = positionDetails.inputTokenBalance
  unstake.inputTokenBalanceNormalizedUSD = positionDetails.inputTokenBalanceNormalizedUSD
  unstake.save()
}
