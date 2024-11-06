import { BigDecimal } from '@graphprotocol/graph-ts'
import { Withdraw } from '../../../generated/schema'
import { Withdraw as WithdrawEvent } from '../../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { PositionDetails } from '../../types'

export function createWithdrawEventEntity(
  event: WithdrawEvent,
  normalizedAmountUSD: BigDecimal,
  positionDetails: PositionDetails,
): void {
  const withdraw = new Withdraw(
    `${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`,
  )
  withdraw.amount = event.params.assets
  withdraw.amountUSD = normalizedAmountUSD
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
