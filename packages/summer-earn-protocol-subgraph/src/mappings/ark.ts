import { Address, BigInt } from '@graphprotocol/graph-ts'
import { Ark as ArkContract } from '../../generated/HarborCommand/Ark'
import { Rebalance } from '../../generated/schema'
import {
  Boarded,
  DepositCapUpdated,
  Disembarked,
  MaxDepositPercentageOfTVLUpdated,
  MaxRebalanceInflowUpdated,
  MaxRebalanceOutflowUpdated,
  Moved,
} from '../../generated/templates/FleetCommanderTemplate/Ark'
import {
  getOrCreateArk,
  getOrCreateArksPostActionSnapshots,
  getOrCreateToken,
  getOrCreateVault,
} from '../common/initializers'
import { getTokenPriceInUSD } from '../common/priceHelpers'
import { formatAmount } from '../common/utils'
import { handleBoard, handleDisembark, handleMove } from './entities/ark'

export function handleBoarded(event: Boarded): void {
  const arkContract = ArkContract.bind(event.address)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.address, event.block)

  if (ark) {
    handleBoard(event.params.amount, ark)
  }
}

export function handleDisembarked(event: Disembarked): void {
  const arkContract = ArkContract.bind(event.address)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.address, event.block)
  if (ark) {
    handleDisembark(event.params.amount, ark)
  }
}

export function handleMoved(event: Moved): void {
  const arkContract = ArkContract.bind(event.params.from)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.params.from, event.block)
  if (ark) {
    handleMove(event.params.amount, ark)
    addRebalanceEvent(event, vaultAddress, event.logIndex.toI32())
  }
}

function addRebalanceEvent(event: Moved, vaultAddress: Address, i: i32): void {
  const vault = getOrCreateVault(vaultAddress, event.block)
  const inputTokenAddress = Address.fromString(vault.inputToken)
  const inputToken = getOrCreateToken(inputTokenAddress)
  const rebalanceEntity = new Rebalance(
    `${event.transaction.hash.toHexString()}-${event.logIndex.toString()}-${i}`,
  )
  const amount = event.params.amount
  const normalizedAmount = formatAmount(amount, BigInt.fromI32(inputToken.decimals))
  const normalizedAmountUSD = normalizedAmount.times(
    getTokenPriceInUSD(inputTokenAddress, event.block).price,
  )

  getOrCreateArk(Address.fromString(vault.id), event.params.from, event.block)
  getOrCreateArk(Address.fromString(vault.id), event.params.to, event.block)

  rebalanceEntity.amount = amount
  rebalanceEntity.amountUSD = normalizedAmountUSD
  rebalanceEntity.from = event.params.from.toHexString()
  rebalanceEntity.to = event.params.to.toHexString()
  rebalanceEntity.fromPostAction = getOrCreateArksPostActionSnapshots(
    Address.fromString(vault.id),
    Address.fromString(event.params.from.toHexString()),
    event.block,
  ).id
  rebalanceEntity.toPostAction = getOrCreateArksPostActionSnapshots(
    Address.fromString(vault.id),
    Address.fromString(event.params.to.toHexString()),
    event.block,
  ).id
  rebalanceEntity.blockNumber = event.block.number
  rebalanceEntity.timestamp = event.block.timestamp
  rebalanceEntity.vault = vault.id
  rebalanceEntity.asset = vault.inputToken
  rebalanceEntity.protocol = vault.protocol
  rebalanceEntity.logIndex = event.logIndex.toI32()
  rebalanceEntity.hash = event.transaction.hash.toHexString()
  rebalanceEntity.save()
}

export function handleDepositCapUpdated(event: DepositCapUpdated): void {
  const arkContract = ArkContract.bind(event.address)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.address, event.block)

  if (ark) {
    ark.depositCap = event.params.newCap
    ark.depositLimit = event.params.newCap
    ark.save()
  }
}

export function handleMaxDepositPercentageOfTVLUpdated(
  event: MaxDepositPercentageOfTVLUpdated,
): void {
  const arkContract = ArkContract.bind(event.address)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.address, event.block)

  if (ark) {
    ark.maxDepositPercentageOfTVL = event.params.newMaxDepositPercentageOfTVL
    ark.save()
  }
}

export function handleMaxRebalanceOutflowUpdated(event: MaxRebalanceOutflowUpdated): void {
  const arkContract = ArkContract.bind(event.address)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.address, event.block)

  if (ark) {
    ark.maxRebalanceOutflow = event.params.newMaxOutflow
    ark.save()
  }
}

export function handleMaxRebalanceInflowUpdated(event: MaxRebalanceInflowUpdated): void {
  const arkContract = ArkContract.bind(event.address)
  const vaultAddress = arkContract.commander()
  const ark = getOrCreateArk(vaultAddress, event.address, event.block)

  if (ark) {
    ark.maxRebalanceInflow = event.params.newMaxInflow
    ark.save()
  }
}
