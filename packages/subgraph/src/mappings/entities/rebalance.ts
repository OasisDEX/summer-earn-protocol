import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Rebalance, Vault } from '../../../generated/schema'
import { Rebalanced as RebalancedEvent } from '../../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { getOrCreateToken } from '../../common/initializers'
import { getTokenPriceInUSD } from '../../common/priceHelpers'
import { formatAmount } from '../../common/utils'

export function createRebalanceEventEntity(
  event: RebalancedEvent,
  vault: Vault,
  block: ethereum.Block,
): void {
  const rebalances = event.params.rebalances
  const inputTokenAddress = Address.fromString(vault.inputToken)
  const inputToken = getOrCreateToken(inputTokenAddress)
  for (let i = 0; i < rebalances.length; i++) {
    const rebalanceEntity = new Rebalance(
      `${event.transaction.hash.toHexString()}-${event.logIndex.toString()}-${i}`,
    )
    const amount = rebalances[i].amount
    const normalizedAmount = formatAmount(amount, BigInt.fromI32(inputToken.decimals))
    const normalizedAmountUSD = normalizedAmount.times(
      getTokenPriceInUSD(inputTokenAddress, block).price,
    )
    const rebalance = rebalances[i]
    rebalanceEntity.amount = rebalance.amount
    rebalanceEntity.amountUSD = normalizedAmountUSD
    rebalanceEntity.from = rebalances[i].fromArk.toHexString()
    rebalanceEntity.to = rebalances[i].toArk.toHexString()
    rebalanceEntity.blockNumber = event.block.number
    rebalanceEntity.timestamp = event.block.timestamp
    rebalanceEntity.vault = vault.id
    rebalanceEntity.asset = vault.inputToken
    rebalanceEntity.protocol = vault.protocol
    rebalanceEntity.logIndex = event.logIndex.toI32()
    rebalanceEntity.hash = event.transaction.hash.toHexString()
    rebalanceEntity.save()
  }
}
