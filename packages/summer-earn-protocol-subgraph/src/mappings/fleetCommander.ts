import { Address } from '@graphprotocol/graph-ts'
import {
  RewardAdded,
  RewardsDurationUpdated,
  RewardTokenRemoved,
  Staked,
  Unstaked,
} from '../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import {
  ArkAdded,
  ArkRemoved,
  Deposit as DepositEvent,
  FleetCommanderDepositCapUpdated,
  FleetCommanderMaxRebalanceOperationsUpdated,
  FleetCommanderminimumBufferBalanceUpdated,
  FleetCommanderStakingRewardsUpdated,
  FleetCommanderWithdrawnFromArks,
  Rebalanced,
  Withdraw as WithdrawEvent,
} from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { ADDRESS_ZERO, BigIntConstants } from '../common/constants'
import {
  getOrCreateAccount,
  getOrCreateArk,
  getOrCreateRewardsManager,
  getOrCreateVault,
} from '../common/initializers'
import { createDepositEventEntity } from './entities/deposit'
import { createStakedEventEntity } from './entities/stake'
import { createUnstakedEventEntity } from './entities/unstake'
import {
  addOrUpdateVaultRewardRates,
  getAndUpdateVaultAndPositionDetails,
  removeVaultRewardRates,
  updateVaultAndArks,
} from './entities/vault'
import { createWithdrawEventEntity } from './entities/withdraw'

export function handleRebalance(event: Rebalanced): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault.id)
  vault.rebalanceCount = vault.rebalanceCount.plus(BigIntConstants.ONE)
  vault.save()
}

export function handleArkAdded(event: ArkAdded): void {
  getOrCreateArk(event.address, event.params.ark, event.block)
}

let _arkAddress: string
export function handleArkRemoved(event: ArkRemoved): void {
  const vaultAddress = event.address
  const vault = getOrCreateVault(vaultAddress, event.block)
  _arkAddress = event.params.ark.toHexString()
  let previousArrayOfArks = vault.arksArray
  vault.arksArray = previousArrayOfArks.filter((ark) => ark !== _arkAddress)
  vault.save()
  // remove relation to vault
  const ark = getOrCreateArk(vaultAddress, Address.fromString(_arkAddress), event.block)
  ark.vault = ADDRESS_ZERO.toHexString()
  ark.save()
}

export function handleDeposit(event: DepositEvent): void {
  const account = getOrCreateAccount(event.params.owner.toHexString())

  const result = getAndUpdateVaultAndPositionDetails(event, event.address, account, event.block)

  createDepositEventEntity(event, result.positionDetails)
}

export function handleWithdraw(event: WithdrawEvent): void {
  const account = getOrCreateAccount(event.params.owner.toHexString())

  const result = getAndUpdateVaultAndPositionDetails(event, event.address, account, event.block)

  createWithdrawEventEntity(event, result.positionDetails)
}

// withdaraw already handled in handleWithdraw
export function handleFleetCommanderWithdrawnFromArks(
  event: FleetCommanderWithdrawnFromArks,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault.id)
}

export function handleFleetCommanderMinimumBufferBalanceUpdated(
  event: FleetCommanderminimumBufferBalanceUpdated,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  if (vault) {
    vault.minimumBufferBalance = event.params.newBalance
    vault.save()
  }
}

export function handleFleetCommanderDepositCapUpdated(
  event: FleetCommanderDepositCapUpdated,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  if (vault) {
    vault.depositCap = event.params.newCap
    vault.save()
  }
}

export function handleFleetCommanderStakingRewardsUpdated(
  event: FleetCommanderStakingRewardsUpdated,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  if (vault) {
    vault.stakingRewardsManager = event.params.newStakingRewards
    getOrCreateRewardsManager(event.params.newStakingRewards)
    vault.save()
  }
}

export function handleFleetCommanderMaxRebalanceOperationsUpdated(
  event: FleetCommanderMaxRebalanceOperationsUpdated,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  if (vault) {
    vault.maxRebalanceOperations = event.params.newMaxRebalanceOperations
    vault.save()
  }
}

export function handleStaked(event: Staked): void {
  const account = getOrCreateAccount(event.params.receiver.toHexString())

  const rewardsManager = getOrCreateRewardsManager(event.address)

  const result = getAndUpdateVaultAndPositionDetails(
    event,
    Address.fromString(rewardsManager.vault),
    account,
    event.block,
  )
  // todo ; add check if the staker was the admirals quarters when it becomes available in the event
  createStakedEventEntity(event, result.positionDetails)
  createDepositEventEntity(event, result.positionDetails)
}

export function handleUnstaked(event: Unstaked): void {
  const account = getOrCreateAccount(event.params.staker.toHexString())

  const rewardsManager = getOrCreateRewardsManager(event.address)

  const result = getAndUpdateVaultAndPositionDetails(
    event,
    Address.fromString(rewardsManager.vault),
    account,
    event.block,
  )

  createUnstakedEventEntity(event, result.positionDetails)
  createWithdrawEventEntity(event, result.positionDetails)
}

export function handleRewardTokenRemoved(event: RewardTokenRemoved): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)

  removeVaultRewardRates(vault, event.params.rewardToken)
}

export function handleRewardAdded(event: RewardAdded): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)

  addOrUpdateVaultRewardRates(vault, event.address, event.params.rewardToken)

  rewardsManager.save()
}

export function handleRewardsDurationUpdated(event: RewardsDurationUpdated): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)

  addOrUpdateVaultRewardRates(vault, event.address, event.params.rewardToken)

  rewardsManager.save()
}
