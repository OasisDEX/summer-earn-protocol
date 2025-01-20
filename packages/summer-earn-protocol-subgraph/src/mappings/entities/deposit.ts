import { BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Deposit, Staked } from '../../../generated/schema'
import { BigIntConstants } from '../../common/constants'
import { PositionDetails } from '../../types'

export function createDepositEventEntity(
  event: ethereum.Event,
  positionDetails: PositionDetails,
): void {
  let staked = Staked.load(`${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`)
  let deposit: Deposit | null = null
  if (staked) {
    deposit = new Deposit(
      `${event.transaction.hash.toHexString()}-${event.logIndex.minus(BigInt.fromI32(1)).toString()}`,
    )
  } else {
    deposit = new Deposit(`${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`)
  }
  deposit.amount = positionDetails.inputTokenDelta
  deposit.amountUSD = positionDetails.inputTokenDeltaNormalizedUSD
  deposit.from = positionDetails.account
  deposit.to = positionDetails.vault
  deposit.blockNumber = event.block.number
  deposit.timestamp = event.block.timestamp
  deposit.vault = positionDetails.vault
  deposit.asset = positionDetails.inputToken.id
  deposit.protocol = positionDetails.protocol
  deposit.logIndex = event.logIndex.toI32()
  deposit.hash = event.transaction.hash.toHexString()
  deposit.position = positionDetails.positionId
  deposit.inputTokenBalance = positionDetails.inputTokenBalance
  deposit.inputTokenBalanceNormalizedUSD = positionDetails.inputTokenBalanceNormalizedUSD
  if (positionDetails.inputTokenDelta.equals(BigIntConstants.ZERO)) {
    return
  }
  deposit.save()
}
