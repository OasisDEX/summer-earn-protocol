import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { Strategy, User } from '../../generated/schema'

export function getOrCreateUser(address: Address, block: ethereum.Block): User {
  let user = User.load(address)
  if (user == null) {
    user = new User(address)
    user.createdAt = block.timestamp
    user.save()
  }
  return user
}

export function loadStrategyOrWarn(strategyId: BigInt, context: string): Strategy | null {
  const id = strategyId.toString()
  const s = Strategy.load(id)
  if (s == null) {
    log.warning('{}: strategy {} not found', [context, id])
  }
  return s
}
