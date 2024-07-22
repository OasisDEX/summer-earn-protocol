import {
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
} from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { getOrCreateAccount, getOrCreateVault } from '../common/initializers'
import { BigInt, ethereum } from '@graphprotocol/graph-ts'
import { formatAmount } from '../common/utils'
import { Account, Vault } from '../../generated/schema'
import { VaultAndPositionDetails } from '../types'
import { getPositionDetails } from '../utils/position'
import { getVaultDetails } from '../utils/vault'
import { createDepositEventEntity } from './entities/deposit'
import { createWithdrawEventEntity } from './entities/withdraw'
import { updatePosition } from './entities/position'
import { updateVault } from './entities/vault'

export function handleDeposit(event: DepositEvent): void {
  const vault = getOrCreateVault(event.address, event.block)
  const account = getOrCreateAccount(event.params.sender.toHexString())

  const result = getAndUpdateVaultAndPositionDetails(event, vault, account)

  const amount = event.params.assets
  const normalizedAmount = formatAmount(
    amount,
    BigInt.fromI32(result.vaultDetails.inputToken.decimals),
  )
  const normalizedAmountUSD = normalizedAmount.times(result.vaultDetails.inputTokenPriceUSD)

  createDepositEventEntity(event, amount, normalizedAmountUSD, result.positionDetails)
}

export function handleWithdraw(event: WithdrawEvent): void {
  const vault = getOrCreateVault(event.address, event.block)
  const account = getOrCreateAccount(event.params.sender.toHexString())

  const result = getAndUpdateVaultAndPositionDetails(event, vault, account)

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
  vault: Vault,
  account: Account,
): VaultAndPositionDetails {
  const vaultDetails = getVaultDetails(event, vault)
  const positionDetails = getPositionDetails(event, account, vaultDetails)
  return { vaultDetails: vaultDetails, positionDetails: positionDetails }
}

function getAndUpdateVaultAndPositionDetails(
  event: ethereum.Event,
  vault: Vault,
  account: Account,
): VaultAndPositionDetails {
  const result = getVaultAndPositionDetails(event, vault, account)

  updateVault(result.vaultDetails, event.block)
  updatePosition(result.positionDetails, event.block)

  return { vaultDetails: result.vaultDetails, positionDetails: result.positionDetails }
}
