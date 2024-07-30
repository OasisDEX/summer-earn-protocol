import { BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Account } from '../../generated/schema'
import {
  ArkAdded,
  Deposit as DepositEvent,
  Rebalanced,
  Withdraw as WithdrawEvent,
} from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { getOrCreateAccount, getOrCreateArk, getOrCreateVault, getOrCreateVaultsPostActionSnapshots } from '../common/initializers'
import { formatAmount } from '../common/utils'
import { VaultAndPositionDetails } from '../types'
import { getPositionDetails } from '../utils/position'
import { getVaultDetails } from '../utils/vault'
import { createDepositEventEntity } from './entities/deposit'
import { updatePosition } from './entities/position'
import { createRebalanceEventEntity } from './entities/rebalance'
import { updateVault } from './entities/vault'
import { createWithdrawEventEntity } from './entities/withdraw'

export function handleRebalance(event: Rebalanced): void {
  const vault = getOrCreateVault(event.address, event.block)
  const vaultDetails = getVaultDetails(event.address, event.block)

  updateVault(vaultDetails, event.block)
  getOrCreateVaultsPostActionSnapshots(event.address, event.block)
  createRebalanceEventEntity(event, vault, event.block)
}

export function handleArkAdded(event: ArkAdded): void {
  getOrCreateArk(event.address, event.params.ark, event.block)
}

export function handleDeposit(event: DepositEvent): void {
  const account = getOrCreateAccount(event.params.sender.toHexString())

  const result = getAndUpdateVaultAndPositionDetails(event, account, event.block)
  const amount = event.params.assets
  const normalizedAmount = formatAmount(
    amount,
    BigInt.fromI32(result.vaultDetails.inputToken.decimals),
  )
  const normalizedAmountUSD = normalizedAmount.times(result.vaultDetails.inputTokenPriceUSD)

  createDepositEventEntity(event, amount, normalizedAmountUSD, result.positionDetails)
}

export function handleWithdraw(event: WithdrawEvent): void {
  const account = getOrCreateAccount(event.params.sender.toHexString())

  const result = getAndUpdateVaultAndPositionDetails(event, account, event.block)
  const amount = event.params.assets
  const normalizedAmount = formatAmount(
    amount,
    BigInt.fromI32(result.vaultDetails.inputToken.decimals),
  )
  const normalizedAmountUSD = normalizedAmount.times(result.vaultDetails.inputTokenPriceUSD)

  createWithdrawEventEntity(event, normalizedAmountUSD, result.positionDetails)
}

function getVaultAndPositionDetails(
  event: ethereum.Event,
  account: Account,
  block: ethereum.Block,
): VaultAndPositionDetails {
  const vaultDetails = getVaultDetails(event.address, block)
  const positionDetails = getPositionDetails(event, account, vaultDetails)
  return { vaultDetails: vaultDetails, positionDetails: positionDetails }
}

function getAndUpdateVaultAndPositionDetails(
  event: ethereum.Event,
  account: Account,
  block: ethereum.Block,
): VaultAndPositionDetails {
  const result = getVaultAndPositionDetails(event, account, block)

  updateVault(result.vaultDetails, event.block)
  updatePosition(result.positionDetails, event.block)

  return { vaultDetails: result.vaultDetails, positionDetails: result.positionDetails }
}
