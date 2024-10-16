import { Address, BigInt } from '@graphprotocol/graph-ts'
import {
  ArkAdded,
  ArkRemoved,
  Deposit as DepositEvent,
  FleetCommanderWithdrawnFromArks,
  Rebalanced,
  Withdraw as WithdrawEvent,
} from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { ADDRESS_ZERO } from '../common/constants'
import { getOrCreateAccount, getOrCreateArk, getOrCreateVault } from '../common/initializers'
import { formatAmount } from '../common/utils'
import { createDepositEventEntity } from './entities/deposit'
import { createRebalanceEventEntity } from './entities/rebalance'
import { getAndUpdateVaultAndPositionDetails, updateVaultAndArks } from './entities/vault'
import { createWithdrawEventEntity } from './entities/withdraw'

export function handleRebalance(event: Rebalanced): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault)
  createRebalanceEventEntity(event, vault, event.block)
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

// withdaraw already handled in handleWithdraw
export function handleFleetCommanderWithdrawnFromArks(
  event: FleetCommanderWithdrawnFromArks,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault)
}
