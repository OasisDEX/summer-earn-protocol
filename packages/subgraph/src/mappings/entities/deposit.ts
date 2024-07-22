import { BigInt, BigDecimal } from '@graphprotocol/graph-ts'
import { Deposit } from '../../../generated/schema'
import { Deposit as DepositEvent } from '../../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { PositionDetails } from '../../types'

export function createDepositEventEntity(
  event: DepositEvent,
  amount: BigInt,
  normalizedAmountUSD: BigDecimal,
  positionDetails: PositionDetails,
): void {
  const deposit = new Deposit(
    `${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`,
  )
  deposit.amount = amount
  deposit.amountUSD = normalizedAmountUSD
  deposit.from = positionDetails.account
  deposit.to = positionDetails.vault
  deposit.blockNumber = event.block.number
  deposit.timestamp = event.block.timestamp
  deposit.vault = positionDetails.vault
  deposit.asset = positionDetails.inputToken.id
  deposit.protocol = positionDetails.protocol
  deposit.logIndex = event.logIndex.toI32()
  deposit.hash = event.transaction.hash.toHexString()
  deposit.save()
}
