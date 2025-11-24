import {
  Staked,
  StakedWithLockup,
  Unstaked,
  UnstakedWithPenalty,
} from '../../generated/SummerStakingV2/SummerStakingV2'
import {
  BigDecimalConstants,
  BigIntConstants,
  SUMMER_STAKING_V2_ADDRESS,
} from '../common/constants'

import { BigInt } from '@graphprotocol/graph-ts'
import {
  getOrCreateAccount,
  getOrCreateGovernanceStakingV2,
  getOrCreateStakeLockup,
} from '../common/initializers'
import { formatAmount } from '../common/utils'

export function handleStaked(event: StakedWithLockup): void {
  const account = getOrCreateAccount(event.params.receiver.toHexString())
  const governanceStaking = getOrCreateGovernanceStakingV2()
  governanceStaking.summerStaked = governanceStaking.summerStaked.plus(event.params.amount)
  governanceStaking.summerStakedNormalized = governanceStaking.summerStakedNormalized.plus(
    formatAmount(event.params.amount, BigInt.fromI32(18)),
  )

  const stakeLockup = getOrCreateStakeLockup(
    event.params.receiver.toHexString() + '-' + event.params.stakeIndex.toHexString(),
  )
  stakeLockup.account = account.id
  stakeLockup.lockupPeriod = event.params.lockupPeriod
  stakeLockup.startTimestamp = event.block.timestamp
  stakeLockup.endTimestamp = event.block.timestamp.plus(event.params.lockupPeriod)
  if (event.params.lockupPeriod.equals(BigIntConstants.ZERO)) {
    stakeLockup.amount = stakeLockup.amount.plus(event.params.amount)
    stakeLockup.amountNormalized = stakeLockup.amountNormalized.plus(
      formatAmount(event.params.amount, BigInt.fromI32(18)),
    )
    stakeLockup.weightedAmount = stakeLockup.weightedAmount.plus(event.params.weightedAmount)
    stakeLockup.weightedAmountNormalized = stakeLockup.weightedAmountNormalized.plus(
      formatAmount(event.params.weightedAmount, BigInt.fromI32(18)),
    )
  } else {
    stakeLockup.amount = event.params.amount
    stakeLockup.amountNormalized = formatAmount(event.params.amount, BigInt.fromI32(18))
    stakeLockup.weightedAmount = event.params.weightedAmount
    stakeLockup.weightedAmountNormalized = formatAmount(
      event.params.weightedAmount,
      BigInt.fromI32(18),
    )
  }

  stakeLockup.save()
  if (governanceStaking.averageLockupPeriod) {
    governanceStaking.amountOfLockedStakes = governanceStaking.amountOfLockedStakes!.plus(
      BigIntConstants.ONE,
    )
    governanceStaking.averageLockupPeriod = governanceStaking
      .averageLockupPeriod!.plus(event.params.lockupPeriod)
      .div(governanceStaking.amountOfLockedStakes!)
  }
  governanceStaking.save()
}

export function handleUnstaked(event: UnstakedWithPenalty): void {
  const account = getOrCreateAccount(event.params.receiver.toHexString())
  const governanceStaking = getOrCreateGovernanceStakingV2()
  governanceStaking.summerStaked = governanceStaking.summerStaked.minus(event.params.unstakedAmount)
  governanceStaking.summerStakedNormalized = governanceStaking.summerStakedNormalized.minus(
    formatAmount(event.params.unstakedAmount, BigInt.fromI32(18)),
  )

  const stakeLockup = getOrCreateStakeLockup(
    event.params.receiver.toHexString() + '-' + event.params.stakeIndex.toHexString(),
  )
  const weightedAmountToRemove = stakeLockup.weightedAmount
    .times(stakeLockup.amount)
    .div(stakeLockup.amount)
  stakeLockup.account = account.id
  stakeLockup.amount = stakeLockup.amount.minus(event.params.unstakedAmount)
  stakeLockup.amountNormalized = stakeLockup.amountNormalized.minus(
    formatAmount(event.params.unstakedAmount, BigInt.fromI32(18)),
  )
  stakeLockup.weightedAmount = stakeLockup.weightedAmount.minus(weightedAmountToRemove)
  stakeLockup.weightedAmountNormalized = stakeLockup.weightedAmountNormalized.minus(
    formatAmount(weightedAmountToRemove, BigInt.fromI32(18)),
  )
  stakeLockup.save()
  if (governanceStaking.averageLockupPeriod && stakeLockup.amount.equals(BigIntConstants.ZERO)) {
    governanceStaking.amountOfLockedStakes = governanceStaking.amountOfLockedStakes!.minus(
      BigIntConstants.ONE,
    )
    governanceStaking.averageLockupPeriod = governanceStaking
      .averageLockupPeriod!.minus(stakeLockup.lockupPeriod)
      .div(governanceStaking.amountOfLockedStakes!)
  }
  governanceStaking.save()
}
