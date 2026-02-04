import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import {
  GovernanceRewardsManager,
  RewardPaid,
  RewardsDurationUpdated,
} from '../../generated/GovernanceRewardsManager/GovernanceRewardsManager'
import { AccountRewards, GovernanceStaking, Token } from '../../generated/schema'
import {
  RewardAdded,
  RewardTokenRemoved,
  Staked,
  Unstaked,
} from '../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import { BigDecimalConstants, BigIntConstants } from '../common/constants'
import {
  getOrCreateAccount,
  getOrCreateRewardToken,
  getOrCreateToken,
} from '../common/initializers'
import { formatAmount } from '../common/utils'

export function getOrCreateGovernanceStaking(): GovernanceStaking {
  let governanceStaking = GovernanceStaking.load('governanceStaking')
  if (!governanceStaking) {
    governanceStaking = new GovernanceStaking('governanceStaking')
    governanceStaking.rewardTokens = []
    governanceStaking.rewardTokenEmissionsAmount = []
    governanceStaking.rewardTokenEmissionsAmountsPerOutputToken = []
    governanceStaking.rewardTokenEmissionsFinish = []
    governanceStaking.rewardTokenEmissionsUSD = []
    governanceStaking.summerStaked = BigIntConstants.ZERO
    governanceStaking.summerStakedNormalized = BigDecimalConstants.ZERO
    governanceStaking.accounts = []
    governanceStaking.averageLockupPeriod = BigIntConstants.ZERO
    governanceStaking.amountOfLockedStakes = BigIntConstants.ZERO
    governanceStaking.weightedAverageLockupPeriod = BigIntConstants.ZERO
    governanceStaking.save()
  }
  return governanceStaking
}
export function getOrCreateAccountRewards(accountId: string, rewardToken: Token): AccountRewards {
  const id = `${accountId}-${rewardToken.id}`
  let accountRewards = AccountRewards.load(id)
  if (!accountRewards) {
    accountRewards = new AccountRewards(id)
    accountRewards.account = accountId
    accountRewards.rewardToken = rewardToken.id
    accountRewards.claimed = BigIntConstants.ZERO
    accountRewards.claimedNormalized = BigDecimalConstants.ZERO
    accountRewards.save()
  }
  return accountRewards
}
export function handleStaked(event: Staked): void {
  const account = getOrCreateAccount(event.params.receiver.toHexString())
  account.stakedSummerToken = account.stakedSummerToken.plus(event.params.amount)
  account.stakedSummerTokenNormalized = account.stakedSummerTokenNormalized.plus(
    formatAmount(event.params.amount, BigInt.fromI32(18)),
  )
  account.save()

  const governanceStaking = getOrCreateGovernanceStaking()
  governanceStaking.summerStaked = governanceStaking.summerStaked.plus(event.params.amount)
  governanceStaking.summerStakedNormalized = governanceStaking.summerStakedNormalized.plus(
    formatAmount(event.params.amount, BigInt.fromI32(18)),
  )
  const index = governanceStaking.accounts.indexOf(account.id)
  if (index == -1) {
    const accounts = governanceStaking.accounts
    accounts.push(account.id)
    governanceStaking.accounts = accounts
  }
  governanceStaking.save()
}

export function handleUnstaked(event: Unstaked): void {
  const account = getOrCreateAccount(event.params.staker.toHexString())

  account.stakedSummerToken = account.stakedSummerToken.minus(event.params.amount)
  account.stakedSummerTokenNormalized = account.stakedSummerTokenNormalized.minus(
    formatAmount(event.params.amount, BigInt.fromI32(18)),
  )
  account.save()

  const governanceStaking = getOrCreateGovernanceStaking()
  governanceStaking.summerStaked = governanceStaking.summerStaked.minus(event.params.amount)
  governanceStaking.summerStakedNormalized = governanceStaking.summerStakedNormalized.minus(
    formatAmount(event.params.amount, BigInt.fromI32(18)),
  )
  governanceStaking.save()
}

export function handleRewardTokenRemoved(event: RewardTokenRemoved): void {
  const governanceStaking = getOrCreateGovernanceStaking()

  removeGovernanceStakingRewardRates(governanceStaking, event.params.rewardToken)
}

export function handleRewardAdded(event: RewardAdded): void {
  const governanceStaking = getOrCreateGovernanceStaking()

  addOrUpdateGovernanceStakingRewardRates(
    governanceStaking,
    event.address,
    event.params.rewardToken,
  )
}

export function handleRewardsDurationUpdated(event: RewardsDurationUpdated): void {
  const governanceStaking = getOrCreateGovernanceStaking()

  addOrUpdateGovernanceStakingRewardRates(
    governanceStaking,
    event.address,
    event.params.rewardToken,
  )
}

export function handleRewardPaid(event: RewardPaid): void {
  const governanceStaking = getOrCreateGovernanceStaking()

  if (governanceStaking.rewardTokens.includes(event.params.rewardToken.toHexString())) {
    const account = getOrCreateAccount(event.params.user.toHexString())

    const accountRewards = getOrCreateAccountRewards(
      account.id,
      getOrCreateToken(event.params.rewardToken),
    )
    accountRewards.claimed = accountRewards.claimed.plus(event.params.reward)
    accountRewards.claimedNormalized = accountRewards.claimedNormalized.plus(
      formatAmount(
        event.params.reward,
        BigInt.fromI32(getOrCreateToken(Address.fromString(accountRewards.rewardToken)).decimals),
      ),
    )
    accountRewards.save()
  }
}
export function removeGovernanceStakingRewardRates(
  governanceStaking: GovernanceStaking,
  rewardToken: Address,
): void {
  const rewardTokens = governanceStaking.rewardTokens
  const index = rewardTokens.indexOf(rewardToken.toHexString())

  if (index !== -1) {
    const rewardTokenEmissionsAmounts = governanceStaking.rewardTokenEmissionsAmount
    const rewardTokenEmissionsAmountsPerOutputToken =
      governanceStaking.rewardTokenEmissionsAmountsPerOutputToken
    const rewardTokenEmissionsFinish = governanceStaking.rewardTokenEmissionsFinish

    rewardTokens.splice(index, 1)
    rewardTokenEmissionsAmounts.splice(index, 1)
    rewardTokenEmissionsAmountsPerOutputToken.splice(index, 1)
    rewardTokenEmissionsFinish.splice(index, 1)

    governanceStaking.rewardTokens = rewardTokens
    governanceStaking.rewardTokenEmissionsAmount = rewardTokenEmissionsAmounts
    governanceStaking.rewardTokenEmissionsAmountsPerOutputToken =
      rewardTokenEmissionsAmountsPerOutputToken
    governanceStaking.rewardTokenEmissionsFinish = rewardTokenEmissionsFinish

    governanceStaking.save()
  }
}

export function addOrUpdateGovernanceStakingRewardRates(
  governanceStaking: GovernanceStaking,
  rewardsManagerAddress: Address,
  rewardToken: Address,
): void {
  const rewardsManagerContract = GovernanceRewardsManager.bind(rewardsManagerAddress)
  const rewardsData = rewardsManagerContract.rewardData(rewardToken)
  const rewardTokens = governanceStaking.rewardTokens
  const index = rewardTokens.indexOf(rewardToken.toHexString())

  if (index !== -1) {
    const rewardTokenEmissionsAmounts = governanceStaking.rewardTokenEmissionsAmount
    rewardTokenEmissionsAmounts[index] = rewardsData
      .getRewardRate()
      .times(BigIntConstants.SECONDS_PER_DAY)
    governanceStaking.rewardTokenEmissionsAmount = rewardTokenEmissionsAmounts

    const rewardTokenEmissionsAmountsPerOutputToken =
      governanceStaking.rewardTokenEmissionsAmountsPerOutputToken
    rewardTokenEmissionsAmountsPerOutputToken[index] = governanceStaking.summerStaked.gt(
      BigIntConstants.ZERO,
    )
      ? rewardsData
          .getRewardRate()
          .times(BigIntConstants.SECONDS_PER_DAY)
          .div(governanceStaking.summerStaked)
      : BigIntConstants.ZERO
    governanceStaking.rewardTokenEmissionsAmountsPerOutputToken =
      rewardTokenEmissionsAmountsPerOutputToken

    const rewardTokenEmissionsFinish = governanceStaking.rewardTokenEmissionsFinish
    rewardTokenEmissionsFinish[index] = rewardsData.getPeriodFinish()
    governanceStaking.rewardTokenEmissionsFinish = rewardTokenEmissionsFinish

    governanceStaking.save()
  } else {
    const rewardTokens = governanceStaking.rewardTokens
    const rewardTokenEntity = getOrCreateRewardToken(rewardToken)
    rewardTokens.push(rewardTokenEntity.id)
    governanceStaking.rewardTokens = rewardTokens

    const rewardTokenEmissionsAmounts = governanceStaking.rewardTokenEmissionsAmount
    rewardTokenEmissionsAmounts.push(
      rewardsData.getRewardRate().times(BigIntConstants.SECONDS_PER_DAY),
    )
    governanceStaking.rewardTokenEmissionsAmount = rewardTokenEmissionsAmounts

    const rewardTokenEmissionsAmountsPerOutputToken =
      governanceStaking.rewardTokenEmissionsAmountsPerOutputToken
    rewardTokenEmissionsAmountsPerOutputToken.push(
      governanceStaking.summerStaked.gt(BigIntConstants.ZERO)
        ? rewardsData
            .getRewardRate()
            .times(BigIntConstants.SECONDS_PER_DAY)
            .div(governanceStaking.summerStaked)
        : BigIntConstants.ZERO,
    )
    governanceStaking.rewardTokenEmissionsAmountsPerOutputToken =
      rewardTokenEmissionsAmountsPerOutputToken

    const rewardTokenEmissionsFinish = governanceStaking.rewardTokenEmissionsFinish
    rewardTokenEmissionsFinish.push(rewardsData.getPeriodFinish())
    governanceStaking.rewardTokenEmissionsFinish = rewardTokenEmissionsFinish

    governanceStaking.save()
  }
}
