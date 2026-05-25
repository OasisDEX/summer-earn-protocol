import { Address, ethereum, log } from '@graphprotocol/graph-ts'
import { RoundsVaultInput as RoundsVaultInputBinding } from '../../generated/RoundsVaultRegistry/RoundsVaultInput'
import { RoundsVaultOutput as RoundsVaultOutputBinding } from '../../generated/RoundsVaultRegistry/RoundsVaultOutput'
import {
  RoundsVaultPairDeactivated,
  RoundsVaultPairReactivated,
  RoundsVaultPairRegistered,
  RoundsVaultPairUpdated,
} from '../../generated/RoundsVaultRegistry/RoundsVaultRegistry'
import { RoundsVault, RoundsVaultPair, Vault } from '../../generated/schema'
import {
  RoundsVaultInputTemplate,
  RoundsVaultOutputTemplate,
} from '../../generated/templates'
import { ADDRESS_ZERO, BigIntConstants } from '../common/constants'
import {
  getOrCreateRound,
  getOrCreateToken,
  getOrCreateVault,
} from '../common/initializers'

export function handleRoundsVaultPairRegistered(event: RoundsVaultPairRegistered): void {
  const pairId = event.params.pairId.toHexString()
  const institutionId = event.params.institutionId.toHex()

  // Ensure the target FleetCommander Vault exists. In production it has already
  // been created via HarborCommand's enlistment event; this is the safety net
  // for out-of-order replay.
  const targetVault = getOrCreateVault(event.params.targetVault, event.block, institutionId)

  const pair = new RoundsVaultPair(pairId)
  pair.institutionId = institutionId
  pair.targetVault = targetVault.id
  pair.active = true
  pair.registeredAt = event.block.timestamp
  pair.registeredAtBlock = event.block.number
  pair.lastUpdated = event.block.timestamp

  if (event.params.inputVault.notEqual(ADDRESS_ZERO)) {
    const inputVault = createRoundsVault(
      event.params.inputVault,
      pair,
      'INPUT',
      event.block,
    )
    pair.inputVault = inputVault.id
    RoundsVaultInputTemplate.create(event.params.inputVault)
  }

  if (event.params.outputVault.notEqual(ADDRESS_ZERO)) {
    const outputVault = createRoundsVault(
      event.params.outputVault,
      pair,
      'OUTPUT',
      event.block,
    )
    pair.outputVault = outputVault.id
    RoundsVaultOutputTemplate.create(event.params.outputVault)
  }

  pair.save()
}

export function handleRoundsVaultPairUpdated(event: RoundsVaultPairUpdated): void {
  const pairId = event.params.pairId.toHexString()
  const pair = RoundsVaultPair.load(pairId)
  if (pair == null) {
    log.warning('RoundsVaultPairUpdated for unknown pair {}', [pairId])
    return
  }

  if (event.params.inputVault.notEqual(ADDRESS_ZERO)) {
    const existing = pair.inputVault
    if (existing == null || existing != event.params.inputVault.toHexString()) {
      const inputVault = createRoundsVault(
        event.params.inputVault,
        pair,
        'INPUT',
        event.block,
      )
      pair.inputVault = inputVault.id
      RoundsVaultInputTemplate.create(event.params.inputVault)
    }
  }

  if (event.params.outputVault.notEqual(ADDRESS_ZERO)) {
    const existing = pair.outputVault
    if (existing == null || existing != event.params.outputVault.toHexString()) {
      const outputVault = createRoundsVault(
        event.params.outputVault,
        pair,
        'OUTPUT',
        event.block,
      )
      pair.outputVault = outputVault.id
      RoundsVaultOutputTemplate.create(event.params.outputVault)
    }
  }

  pair.lastUpdated = event.block.timestamp
  pair.save()
}

export function handleRoundsVaultPairDeactivated(event: RoundsVaultPairDeactivated): void {
  const pairId = event.params.pairId.toHexString()
  const pair = RoundsVaultPair.load(pairId)
  if (pair == null) {
    return
  }
  pair.active = false
  pair.lastUpdated = event.block.timestamp
  pair.save()
}

export function handleRoundsVaultPairReactivated(event: RoundsVaultPairReactivated): void {
  const pairId = event.params.pairId.toHexString()
  const pair = RoundsVaultPair.load(pairId)
  if (pair == null) {
    return
  }
  pair.active = true
  pair.lastUpdated = event.block.timestamp
  pair.save()
}

function createRoundsVault(
  vaultAddr: Address,
  pair: RoundsVaultPair,
  flavor: string,
  block: ethereum.Block,
): RoundsVault {
  const id = vaultAddr.toHexString()
  let vault = RoundsVault.load(id)
  if (vault != null) {
    return vault
  }
  vault = new RoundsVault(id)
  vault.pair = pair.id
  vault.flavor = flavor
  vault.currentRound = BigIntConstants.ZERO
  vault.minPositionSize = BigIntConstants.ZERO
  vault.cumulativeDepositsQueued = BigIntConstants.ZERO
  vault.cumulativeExchangeAssetWithdrawn = BigIntConstants.ZERO
  vault.currentRoundReceiptSupply = BigIntConstants.ZERO
  vault.pendingSettlementAmount = BigIntConstants.ZERO
  vault.createdAt = block.timestamp
  vault.createdAtBlock = block.number

  // Both flavors expose asset() (underlying user-side) and exchangeAsset()
  // (what users receive at settlement). Either binding works; the flavor only
  // determines which side maps to which token.
  let assetAddr: Address
  let exchangeAddr: Address
  if (flavor == 'INPUT') {
    const binding = RoundsVaultInputBinding.bind(vaultAddr)
    const assetRes = binding.try_asset()
    const exchangeRes = binding.try_exchangeAsset()
    const minPosRes = binding.try_minPositionSize()
    assetAddr = assetRes.reverted ? ADDRESS_ZERO : assetRes.value
    exchangeAddr = exchangeRes.reverted ? ADDRESS_ZERO : exchangeRes.value
    if (!minPosRes.reverted) {
      vault.minPositionSize = minPosRes.value
    }
  } else {
    const binding = RoundsVaultOutputBinding.bind(vaultAddr)
    const assetRes = binding.try_asset()
    const exchangeRes = binding.try_exchangeAsset()
    const minPosRes = binding.try_minPositionSize()
    assetAddr = assetRes.reverted ? ADDRESS_ZERO : assetRes.value
    exchangeAddr = exchangeRes.reverted ? ADDRESS_ZERO : exchangeRes.value
    if (!minPosRes.reverted) {
      vault.minPositionSize = minPosRes.value
    }
  }

  const underlying = getOrCreateToken(assetAddr)
  const exchange = getOrCreateToken(exchangeAddr)
  vault.underlyingToken = underlying.id
  vault.exchangeAssetToken = exchange.id
  vault.save()

  // Seed the initial round (roundId=0) so receipt entities can reference it
  // before the first explicit RoundAdvanced event fires.
  getOrCreateRound(vault, BigIntConstants.ZERO, block)

  return vault
}
