import { Address, BigInt } from '@graphprotocol/graph-ts'
import {
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
import { ADDRESS_ZERO } from '../common/constants'
import {
  getOrCreateAccount,
  getOrCreateArk,
  getOrCreateRewardsManager,
  getOrCreateVault,
} from '../common/initializers'
import { formatAmount } from '../common/utils'
import { createDepositEventEntity } from './entities/deposit'
import { createStakedEventEntity } from './entities/stake'
import { createUnstakedEventEntity } from './entities/unstake'
import { getAndUpdateVaultAndPositionDetails, updateVaultAndArks } from './entities/vault'
import { createWithdrawEventEntity } from './entities/withdraw'

export function handleRebalance(event: Rebalanced): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault)
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
  const amount = event.params.assets
  const normalizedAmount = formatAmount(
    amount,
    BigInt.fromI32(result.vaultDetails.inputToken.decimals),
  )
  const normalizedAmountUSD = normalizedAmount.times(result.vaultDetails.inputTokenPriceUSD)

  createDepositEventEntity(event, amount, normalizedAmountUSD, result.positionDetails)
}

export function handleWithdraw(event: WithdrawEvent): void {
  const account = getOrCreateAccount(event.params.owner.toHexString())

  const result = getAndUpdateVaultAndPositionDetails(event, event.address, account, event.block)
  const amount = event.params.assets
  const normalizedAmount = formatAmount(
    amount,
    BigInt.fromI32(result.vaultDetails.inputToken.decimals),
  )
  const normalizedAmountUSD = normalizedAmount.times(result.vaultDetails.inputTokenPriceUSD)

  createWithdrawEventEntity(event, normalizedAmountUSD, result.positionDetails)
}

// withdaraw already handled in handleWithdraw
export function handleFleetCommanderWithdrawnFromArks(
  event: FleetCommanderWithdrawnFromArks,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault)
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
  const account = getOrCreateAccount(event.params.account.toHexString())

  const rewardsManager = getOrCreateRewardsManager(event.address)

  const result = getAndUpdateVaultAndPositionDetails(
    event,
    Address.fromString(rewardsManager.vault),
    account,
    event.block,
  )
  const amount = event.params.amount
  const normalizedAmount = formatAmount(
    amount,
    BigInt.fromI32(result.vaultDetails.inputToken.decimals),
  )
  const normalizedAmountUSD = normalizedAmount.times(result.vaultDetails.inputTokenPriceUSD)

  createStakedEventEntity(event, amount, normalizedAmountUSD, result.positionDetails)
}

export function handleUnstaked(event: Unstaked): void {
  const account = getOrCreateAccount(event.params.account.toHexString())

  const rewardsManager = getOrCreateRewardsManager(event.address)

  const result = getAndUpdateVaultAndPositionDetails(
    event,
    Address.fromString(rewardsManager.vault),
    account,
    event.block,
  )
  const amount = event.params.amount
  const normalizedAmount = formatAmount(
    amount,
    BigInt.fromI32(result.vaultDetails.inputToken.decimals),
  )
  const normalizedAmountUSD = normalizedAmount.times(result.vaultDetails.inputTokenPriceUSD)

  createUnstakedEventEntity(event, amount, normalizedAmountUSD, result.positionDetails)
}
