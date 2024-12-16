import { ethereum } from '@graphprotocol/graph-ts'
import { Withdraw } from '../../../generated/schema'
import { PositionDetails } from '../../types'

export function createWithdrawEventEntity(
  event: ethereum.Event,
  positionDetails: PositionDetails,
): void {
  const withdraw = new Withdraw(
    `${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`,
  )
  withdraw.amount = positionDetails.inputTokenDelta
  withdraw.amountUSD = positionDetails.inputTokenDeltaNormalizedUSD
  withdraw.from = positionDetails.account
  withdraw.to = positionDetails.vault
  withdraw.blockNumber = event.block.number
  withdraw.timestamp = event.block.timestamp
  withdraw.vault = positionDetails.vault
  withdraw.asset = positionDetails.inputToken.id
  withdraw.protocol = positionDetails.protocol
  withdraw.logIndex = event.logIndex.toI32()
  withdraw.hash = event.transaction.hash.toHexString()
  withdraw.position = positionDetails.positionId
  withdraw.inputTokenBalance = positionDetails.inputTokenBalance
  withdraw.inputTokenBalanceNormalizedUSD = positionDetails.inputTokenBalanceNormalizedUSD
  withdraw.save()
}
