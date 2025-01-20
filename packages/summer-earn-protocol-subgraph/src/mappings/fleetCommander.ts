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
import { getPositionDetails } from '../utils/position'
import { getVaultDetails } from '../utils/vault'
import { createDepositEventEntity } from './entities/deposit'
import { updatePosition } from './entities/position'
import { createStakedEventEntity } from './entities/stake'
import { createUnstakedEventEntity } from './entities/unstake'
import {
  addOrUpdateVaultRewardRates,
  removeVaultRewardRates,
  updateVault,
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
  const vaultAddress = event.address
  const account = getOrCreateAccount(event.params.owner.toHexString())

  const vaultDetails = getVaultDetails(vaultAddress, event.block)
  const positionDetails = getPositionDetails(
    vaultAddress,
    Address.fromString(account.id),
    vaultDetails,
    event.block,
  )

  updateVault(vaultDetails, event.block, false)
  updatePosition(positionDetails, event.block)

  createDepositEventEntity(event, positionDetails)
}

export function handleWithdraw(event: WithdrawEvent): void {
  const vaultAddress = event.address

  const vaultDetails = getVaultDetails(vaultAddress, event.block)
  updateVault(vaultDetails, event.block, false)

  const rewardsManager = vaultDetails.rewardsManager

  if (rewardsManager.toHexString() == event.params.owner.toHexString()) {
    // if the owner is the rewards manager, then we skip event creation and position update
    return
  }

  getOrCreateAccount(event.params.owner.toHexString())

  const positionDetails = getPositionDetails(
    vaultAddress,
    event.params.owner,
    vaultDetails,
    event.block,
  )
  updatePosition(positionDetails, event.block)

  createWithdrawEventEntity(event, positionDetails)
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
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vaultAddress = Address.fromString(rewardsManager.vault)
  const account = getOrCreateAccount(event.params.receiver.toHexString())

  const vaultDetails = getVaultDetails(vaultAddress, event.block)
  const positionDetails = getPositionDetails(
    vaultAddress,
    Address.fromString(account.id),
    vaultDetails,
    event.block,
  )

  updateVault(vaultDetails, event.block, false)
  updatePosition(positionDetails, event.block)

  createStakedEventEntity(event, positionDetails)
  createDepositEventEntity(event, positionDetails)
}

export function handleUnstaked(event: Unstaked): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vaultAddress = Address.fromString(rewardsManager.vault)
  const account = getOrCreateAccount(event.params.staker.toHexString())

  const vaultDetails = getVaultDetails(vaultAddress, event.block)
  const positionDetails = getPositionDetails(
    vaultAddress,
    Address.fromString(account.id),
    vaultDetails,
    event.block,
  )

  updateVault(vaultDetails, event.block, false)
  updatePosition(positionDetails, event.block)

  createUnstakedEventEntity(event, positionDetails)
  createWithdrawEventEntity(event, positionDetails)
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
