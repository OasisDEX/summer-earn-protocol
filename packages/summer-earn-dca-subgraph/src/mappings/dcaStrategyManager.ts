import { BigInt } from '@graphprotocol/graph-ts'
import {
  ExecutionCompleted,
  StrategyCancelled,
  StrategyCompleted,
  StrategyCreated,
  StrategyEdited,
  StrategyPaused,
  StrategyResumed,
} from '../../generated/DCAStrategyManager/DCAStrategyManager'
import { Execution, Strategy } from '../../generated/schema'
import { BigIntConstants, StrategyStatus } from '../common/constants'
import { getOrCreateUser, loadStrategyOrWarn, registerFeed } from '../common/initializers'

function updateStrategyStatus(s: Strategy, blockTimestamp: BigInt): void {
  if (s.status == StrategyStatus.PAUSED || s.status == StrategyStatus.CANCELLED) {
    return
  }

  if (s.tradesExecuted.ge(s.maxTrades) || blockTimestamp.ge(s.endDate)) {
    s.status = StrategyStatus.COMPLETED
  } else {
    s.status = StrategyStatus.ACTIVE
  }
}

export function handleStrategyCreated(event: StrategyCreated): void {
  const cfg = event.params.config
  const user = getOrCreateUser(cfg.owner, event.block)

  // Spin up the polling template for any feed we haven't seen before. From
  // this block forward the subgraph will sample `latestRoundData` ~every 5 min.
  registerFeed(cfg.inAssetFeed, event.block)
  registerFeed(cfg.outAssetFeed, event.block)

  const s = new Strategy(event.params.strategyId.toString())
  s.strategyId = event.params.strategyId
  s.owner = user.id

  s.sourceVault = cfg.sourceVault
  s.targetVault = cfg.targetVault
  s.inAsset = cfg.inAsset
  s.outAsset = cfg.outAsset
  s.inAssetFeed = cfg.inAssetFeed
  s.outAssetFeed = cfg.outAssetFeed

  s.tradeAmount = cfg.tradeAmount
  s.interval = cfg.interval
  s.slippageBps = cfg.slippageBps
  s.maxPrice = cfg.maxPrice
  s.minPrice = cfg.minPrice
  s.endDate = cfg.endDate
  s.maxTrades = cfg.maxTrades

  s.status = StrategyStatus.ACTIVE
  s.tradesExecuted = BigIntConstants.ZERO
  s.totalInAssetSwapped = BigIntConstants.ZERO
  s.totalOutAssetReceived = BigIntConstants.ZERO

  // Mirror DCAStrategyManager.sol:67-72 — align to next hourly boundary.
  const hourAligned = event.block.timestamp
    .plus(BigIntConstants.HOUR_MINUS_ONE)
    .div(BigIntConstants.HOUR)
    .times(BigIntConstants.HOUR)
  s.lastScheduledAt = hourAligned
  s.nextTriggerAt = hourAligned.plus(cfg.interval)

  updateStrategyStatus(s, event.block.timestamp)

  s.createdAt = event.block.timestamp
  s.createdAtBlock = event.block.number
  s.updatedAt = event.block.timestamp
  s.updatedAtBlock = event.block.number

  s.save()
}

export function handleStrategyEdited(event: StrategyEdited): void {
  const s = loadStrategyOrWarn(event.params.strategyId, 'handleStrategyEdited')
  if (s == null) return

  const cfg = event.params.config
  const user = getOrCreateUser(cfg.owner, event.block)

  // Edits may swap in a previously-unseen feed pair — register them too.
  registerFeed(cfg.inAssetFeed, event.block)
  registerFeed(cfg.outAssetFeed, event.block)

  // Update configurable fields, including owner and vault/asset configs
  s.owner = user.id
  s.sourceVault = cfg.sourceVault
  s.targetVault = cfg.targetVault
  s.inAsset = cfg.inAsset
  s.outAsset = cfg.outAsset
  s.inAssetFeed = cfg.inAssetFeed
  s.outAssetFeed = cfg.outAssetFeed

  s.tradeAmount = cfg.tradeAmount
  s.interval = cfg.interval
  s.slippageBps = cfg.slippageBps
  s.maxPrice = cfg.maxPrice
  s.minPrice = cfg.minPrice
  s.endDate = cfg.endDate
  s.maxTrades = cfg.maxTrades

  // Mirror DCAStrategyManager.sol:86-88.
  s.nextTriggerAt = s.lastScheduledAt.plus(cfg.interval)

  // Recalculate status in case the edit changed maxTrades or endDate
  updateStrategyStatus(s, event.block.timestamp)

  s.updatedAt = event.block.timestamp
  s.updatedAtBlock = event.block.number
  s.save()
}

export function handleStrategyPaused(event: StrategyPaused): void {
  const s = loadStrategyOrWarn(event.params.strategyId, 'handleStrategyPaused')
  if (s == null) return

  s.status = StrategyStatus.PAUSED
  s.nextTriggerAt = event.params.nextTriggerAt
  s.updatedAt = event.block.timestamp
  s.updatedAtBlock = event.block.number
  s.save()
}

export function handleStrategyResumed(event: StrategyResumed): void {
  const s = loadStrategyOrWarn(event.params.strategyId, 'handleStrategyResumed')
  if (s == null) return

  s.status = StrategyStatus.ACTIVE
  s.nextTriggerAt = event.params.nextTriggerAt
  updateStrategyStatus(s, event.block.timestamp)

  s.updatedAt = event.block.timestamp
  s.updatedAtBlock = event.block.number
  s.save()
}

export function handleStrategyCancelled(event: StrategyCancelled): void {
  const s = loadStrategyOrWarn(event.params.strategyId, 'handleStrategyCancelled')
  if (s == null) return

  s.status = StrategyStatus.CANCELLED
  s.updatedAt = event.block.timestamp
  s.updatedAtBlock = event.block.number
  s.save()
}

export function handleStrategyCompleted(event: StrategyCompleted): void {
  const s = loadStrategyOrWarn(event.params.strategyId, 'handleStrategyCompleted')
  if (s == null) return

  s.status = StrategyStatus.COMPLETED
  s.updatedAt = event.block.timestamp
  s.updatedAtBlock = event.block.number
  s.save()
}

export function handleExecutionCompleted(event: ExecutionCompleted): void {
  const s = loadStrategyOrWarn(event.params.strategyId, 'handleExecutionCompleted')
  if (s == null) return

  const execId = s.id + '-' + event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  const exec = new Execution(execId)
  exec.strategy = s.id
  exec.inAssets = event.params.inAssets
  exec.outAssets = event.params.outAssets
  exec.inShares = event.params.inShares
  exec.outShares = event.params.outShares
  exec.tradesExecutedAfter = event.params.tradesExecuted
  exec.executionTimestamp = event.block.timestamp
  exec.blockNumber = event.block.number
  exec.logIndex = event.logIndex.toI32()
  exec.txHash = event.transaction.hash
  exec.save()

  s.tradesExecuted = event.params.tradesExecuted
  s.nextTriggerAt = event.params.nextTriggerAt
  s.lastScheduledAt = event.block.timestamp

  s.totalInAssetSwapped = s.totalInAssetSwapped.plus(event.params.inAssets)
  s.totalOutAssetReceived = s.totalOutAssetReceived.plus(event.params.outAssets)

  // Recalculate status to check if it has reached maxTrades or endDate
  updateStrategyStatus(s, event.block.timestamp)

  s.updatedAt = event.block.timestamp
  s.updatedAtBlock = event.block.number
  s.save()
}
