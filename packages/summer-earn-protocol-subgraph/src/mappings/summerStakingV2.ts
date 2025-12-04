import {
  StakedWithLockup,
  UnstakedWithPenalty,
} from '../../generated/SummerStakingV2/SummerStakingV2'
import { BigIntConstants } from '../common/constants'

import { Address, BigInt, log, store } from '@graphprotocol/graph-ts'
import {
  getOrCreateAccount,
  getOrCreateGovernanceStakingV2,
  getOrCreateStakeLockup,
} from '../common/initializers'
import { formatAmount } from '../common/utils'
import { StakeLockup } from '../../generated/schema'

export function handleStaked(event: StakedWithLockup): void {
  const processedStakeId = _getStakeLockupId(
    event.address,
    event.params.receiver,
    event.params.stakeIndex,
  )
  const processedStake = getOrCreateStakeLockup(processedStakeId)
  const isNoLockupStake = _isNoLockupStake(event.params.stakeIndex)
  const lockupPeriod = event.params.lockupPeriod

  _processStakeLockupOnStake(processedStake, event)
  _processGovernanceStakingOnStake(event, isNoLockupStake, lockupPeriod)
}

export function handleUnstaked(event: UnstakedWithPenalty): void {
  const processedStakeId = _getStakeLockupId(
    event.address,
    event.params.receiver,
    event.params.stakeIndex,
  )
  const processedStake = getOrCreateStakeLockup(processedStakeId)
  const isNoLockupStake = _isNoLockupStake(event.params.stakeIndex)
  const lockupPeriod = processedStake.lockupPeriod

  const wasStakeEmptied = _processStakeLockupOnUnstake(processedStake, event)

  if (wasStakeEmptied && !isNoLockupStake) {
    _processStakeIndices(event, processedStakeId)
  }

  _processGovernanceStakingOnUnstake(event, isNoLockupStake, lockupPeriod, wasStakeEmptied)
}

function _getStakeLockupId(stakingAddress: Address, receiver: Address, stakeIndex: BigInt): string {
  return (
    stakingAddress.toHexString() + '-' + receiver.toHexString() + '-' + stakeIndex.toHexString()
  )
}

function _isNoLockupStake(stakeIndex: BigInt): boolean {
  return stakeIndex.equals(BigIntConstants.ZERO)
}

function _isStakeEmpty(stake: StakeLockup): boolean {
  return stake.amount.equals(BigIntConstants.ZERO)
}

function _processStakeLockupOnStake(processedStake: StakeLockup, event: StakedWithLockup): void {
  const account = getOrCreateAccount(event.params.receiver.toHexString())
  processedStake.index = event.params.stakeIndex
  processedStake.account = account.id
  processedStake.lockupPeriod = event.params.lockupPeriod
  processedStake.startTimestamp = event.block.timestamp
  processedStake.endTimestamp = event.block.timestamp.plus(event.params.lockupPeriod)

  if (_isNoLockupStake(event.params.stakeIndex)) {
    processedStake.amount = processedStake.amount.plus(event.params.amount)
    processedStake.amountNormalized = processedStake.amountNormalized.plus(
      formatAmount(event.params.amount, BigInt.fromI32(18)),
    )
    processedStake.weightedAmount = processedStake.weightedAmount.plus(event.params.weightedAmount)
    processedStake.weightedAmountNormalized = processedStake.weightedAmountNormalized.plus(
      formatAmount(event.params.weightedAmount, BigInt.fromI32(18)),
    )
  } else {
    processedStake.amount = event.params.amount
    processedStake.amountNormalized = formatAmount(event.params.amount, BigInt.fromI32(18))
    processedStake.weightedAmount = event.params.weightedAmount
    processedStake.weightedAmountNormalized = formatAmount(
      event.params.weightedAmount,
      BigInt.fromI32(18),
    )
  }
  processedStake.save()
}

function _processStakeLockupOnUnstake(
  processedStake: StakeLockup,
  event: UnstakedWithPenalty,
): boolean {
  const weightedAmountToRemove = processedStake.weightedAmount
    .times(event.params.unstakedAmount)
    .div(processedStake.amount)

  processedStake.amount = processedStake.amount.minus(event.params.unstakedAmount)
  processedStake.amountNormalized = processedStake.amountNormalized.minus(
    formatAmount(event.params.unstakedAmount, BigInt.fromI32(18)),
  )
  processedStake.weightedAmount = processedStake.weightedAmount.minus(weightedAmountToRemove)
  processedStake.weightedAmountNormalized = processedStake.weightedAmountNormalized.minus(
    formatAmount(weightedAmountToRemove, BigInt.fromI32(18)),
  )
  processedStake.save()

  return _isStakeEmpty(processedStake)
}

function _processGovernanceStakingOnStake(
  event: StakedWithLockup,
  isNoLockupStake: boolean,
  lockupPeriod: BigInt,
): void {
  const governanceStaking = getOrCreateGovernanceStakingV2(event.address)
  if (!isNoLockupStake) {
    governanceStaking.averageLockupPeriod = governanceStaking.averageLockupPeriod
      .times(governanceStaking.amountOfLockedStakes)
      .plus(lockupPeriod)
      .div(governanceStaking.amountOfLockedStakes.plus(BigIntConstants.ONE))

    governanceStaking.weightedAverageLockupPeriod = governanceStaking.summerStaked
      .times(governanceStaking.weightedAverageLockupPeriod)
      .plus(event.params.amount.times(lockupPeriod))
      .div(governanceStaking.summerStaked.plus(event.params.amount))

    governanceStaking.amountOfLockedStakes = governanceStaking.amountOfLockedStakes.plus(
      BigIntConstants.ONE,
    )
  }
  governanceStaking.summerStaked = governanceStaking.summerStaked.plus(event.params.amount)
  governanceStaking.summerStakedNormalized = governanceStaking.summerStakedNormalized.plus(
    formatAmount(event.params.amount, BigInt.fromI32(18)),
  )

  governanceStaking.save()
}

function _processGovernanceStakingOnUnstake(
  event: UnstakedWithPenalty,
  isNoLockupStake: boolean,
  lockupPeriod: BigInt,
  wasStakeEmptied: boolean,
): void {
  const governanceStaking = getOrCreateGovernanceStakingV2(event.address)
  if (!isNoLockupStake) {
    governanceStaking.weightedAverageLockupPeriod = governanceStaking.weightedAverageLockupPeriod
      .times(governanceStaking.summerStaked)
      .minus(event.params.unstakedAmount.times(lockupPeriod))
      .div(governanceStaking.summerStaked.minus(event.params.unstakedAmount))
    if (wasStakeEmptied) {
      governanceStaking.averageLockupPeriod = governanceStaking.amountOfLockedStakes
        .times(governanceStaking.averageLockupPeriod)
        .minus(lockupPeriod)
        .div(governanceStaking.amountOfLockedStakes.minus(BigIntConstants.ONE))
      governanceStaking.amountOfLockedStakes = governanceStaking.amountOfLockedStakes.minus(
        BigIntConstants.ONE,
      )
    }
  }
  governanceStaking.summerStaked = governanceStaking.summerStaked.minus(event.params.unstakedAmount)
  governanceStaking.summerStakedNormalized = governanceStaking.summerStakedNormalized.minus(
    formatAmount(event.params.unstakedAmount, BigInt.fromI32(18)),
  )
  governanceStaking.save()
}

function _processStakeIndices(event: UnstakedWithPenalty, processedStakeId: string): void {
  const account = getOrCreateAccount(event.params.receiver.toHexString())
  const accountAmountOfLockedStakes = account.stakeLockups.load().length
  const lastStakeIndex = BigInt.fromI32(accountAmountOfLockedStakes - 1)

  if (event.params.stakeIndex.equals(lastStakeIndex)) {
    store.remove('StakeLockup', processedStakeId)
    return
  }

  const lastStakeLockupId = _getStakeLockupId(event.address, event.params.receiver, lastStakeIndex)
  const maybeLastStakeLockup = StakeLockup.load(lastStakeLockupId)
  if (!maybeLastStakeLockup) {
    log.error('Last stake lockup not found: {}', [lastStakeLockupId])
    return
  }
  const lastStakeLockup = maybeLastStakeLockup

  store.remove('StakeLockup', processedStakeId)
  lastStakeLockup.index = event.params.stakeIndex
  lastStakeLockup.id = processedStakeId
  lastStakeLockup.save()
  if (lastStakeLockupId != lastStakeLockup.id) {
    store.remove('StakeLockup', lastStakeLockupId)
  }
}
