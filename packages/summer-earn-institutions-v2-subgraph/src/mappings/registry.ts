import { Address, ethereum, log } from '@graphprotocol/graph-ts'
import { RoundsVaultInput as RoundsVaultInputBinding } from '../../generated/RoundsVaultRegistry/RoundsVaultInput'
import { RoundsVaultOutput as RoundsVaultOutputBinding } from '../../generated/RoundsVaultRegistry/RoundsVaultOutput'
import {
  RoundsVaultPairDeactivated,
  RoundsVaultPairReactivated,
  RoundsVaultPairRegistered,
  RoundsVaultPairUpdated,
} from '../../generated/RoundsVaultRegistry/RoundsVaultRegistry'
import { Institution, RoundsVault, RoundsVaultPair, Vault } from '../../generated/schema'
import { RoundsVaultInputTemplate, RoundsVaultOutputTemplate } from '../../generated/templates'
import { ADDRESS_ZERO, BigIntConstants } from '../common/constants'
import { matchRoundsVaultRole } from '../common/hashHelpers'
import { getOrCreateRound, getOrCreateToken, getOrCreateVault } from '../common/initializers'

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
    const inputVault = createRoundsVault(event.params.inputVault, pair, 'INPUT', event.block)
    pair.inputVault = inputVault.id
    RoundsVaultInputTemplate.create(event.params.inputVault)
  }

  if (event.params.outputVault.notEqual(ADDRESS_ZERO)) {
    const outputVault = createRoundsVault(event.params.outputVault, pair, 'OUTPUT', event.block)
    pair.outputVault = outputVault.id
    RoundsVaultOutputTemplate.create(event.params.outputVault)
  }

  pair.save()

  decodeRoundsVaultRolesForInstitution(
    institutionId,
    event.params.inputVault,
    event.params.outputVault,
  )
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
      const inputVault = createRoundsVault(event.params.inputVault, pair, 'INPUT', event.block)
      pair.inputVault = inputVault.id
      RoundsVaultInputTemplate.create(event.params.inputVault)
    }
  }

  if (event.params.outputVault.notEqual(ADDRESS_ZERO)) {
    const existing = pair.outputVault
    if (existing == null || existing != event.params.outputVault.toHexString()) {
      const outputVault = createRoundsVault(event.params.outputVault, pair, 'OUTPUT', event.block)
      pair.outputVault = outputVault.id
      RoundsVaultOutputTemplate.create(event.params.outputVault)
    }
  }

  pair.lastUpdated = event.block.timestamp
  pair.save()

  decodeRoundsVaultRolesForInstitution(
    pair.institutionId,
    event.params.inputVault,
    event.params.outputVault,
  )
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

// Rounds-vault KEEPER/OPERATOR roles are granted on-chain BEFORE the pair is
// registered (see deploy-whitelisted-fleet.ts), so handleRoleGranted can't yet
// know the vault addresses and leaves those roles undecoded (name == raw hash,
// targetContract == ADDRESS_ZERO). Once we learn the addresses here, back-fill
// any matching undecoded roles for the institution.
function decodeRoundsVaultRolesForInstitution(
  institutionId: string,
  inputVault: Address,
  outputVault: Address,
): void {
  const roundsVaultAddresses: string[] = []
  if (inputVault.notEqual(ADDRESS_ZERO)) {
    roundsVaultAddresses.push(inputVault.toHexString())
  }
  if (outputVault.notEqual(ADDRESS_ZERO)) {
    roundsVaultAddresses.push(outputVault.toHexString())
  }
  if (roundsVaultAddresses.length == 0) {
    return
  }

  const institution = Institution.load(institutionId)
  if (institution == null) {
    return
  }

  const zero = ADDRESS_ZERO.toHexString()
  const roles = institution.roles.load()
  for (let i = 0; i < roles.length; i++) {
    const role = roles[i]
    // Only touch still-undecoded roles. Decoded contract-specific roles already
    // carry a real target; global/whitelist roles either carry a non-rounds
    // target or a hash that can't match a rounds vault — never reclassify them.
    if (role.targetContract != zero) {
      continue
    }
    // Role id is `{accessController}-{roleHash}-{account}` — the middle segment
    // is the on-chain role hash to match against the rounds-vault candidates.
    const parts = role.id.split('-')
    if (parts.length < 2) {
      continue
    }
    const match = matchRoundsVaultRole(parts[1], roundsVaultAddresses)
    if (match) {
      role.name = match.name
      role.targetContract = match.target
      role.save()
    }
  }
}
