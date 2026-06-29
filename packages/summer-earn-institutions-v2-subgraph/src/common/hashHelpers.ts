import { Address, ByteArray, Bytes, crypto } from '@graphprotocol/graph-ts'
import { ProtocolAccessManager } from '../../generated/InstitutionalVaultRegistry/ProtocolAccessManager'
import { ContractSpecificRole, RoleName } from './constants'

function getHash(name: string): string {
  return crypto.keccak256(ByteArray.fromUTF8(name)).toHexString()
}

export const ROLE_MAP = new Map<string, string>()
  .set(getHash(RoleName.GUARDIAN_ROLE), RoleName.GUARDIAN_ROLE)
  .set(getHash(RoleName.SUPER_KEEPER_ROLE), RoleName.SUPER_KEEPER_ROLE)
  .set(getHash(RoleName.DECAY_CONTROLLER_ROLE), RoleName.DECAY_CONTROLLER_ROLE)
  .set(getHash(RoleName.ADMIRALS_QUARTERS_ROLE), RoleName.ADMIRALS_QUARTERS_ROLE)
  .set(getHash(RoleName.FOUNDATION_ROLE), RoleName.FOUNDATION_ROLE)
  .set(getHash(RoleName.GOVERNOR_ROLE), RoleName.GOVERNOR_ROLE)
  .set(getHash(RoleName.WHITELIST_MANAGER_ROLE), RoleName.WHITELIST_MANAGER_ROLE)

export function hasRole(role: Bytes, account: Address, accessManager: Address): boolean {
  const protocolAccessControllerEntity = ProtocolAccessManager.bind(accessManager)
  const hasRole = protocolAccessControllerEntity.try_hasRole(role, account)
  if (hasRole.reverted) {
    return false
  }
  return hasRole.value
}

export function generateContractSpecificRole(
  role: ContractSpecificRole,
  contractAddress: string,
): string {
  // Solidity: keccak256(abi.encodePacked(uint8(role), address(contractAddress)))
  const addr: Address = Address.fromString(contractAddress)
  assert(addr.length == 20)
  const packed = new ByteArray(1 + addr.length)
  packed[0] = <u8>role
  // copy 20-byte address
  for (let i = 0; i < addr.length; i++) {
    packed[1 + i] = addr[i]
  }
  return crypto.keccak256(packed).toHexString()
}

/// based on iterae over array of fleet addresses to get the correct role or return null if not found
export function getContractSpecificRoleName(
  roleHash: string,
  role: ContractSpecificRole,
  fleetAddresses: string[],
): string | null {
  for (let i = 0; i < fleetAddresses.length; i++) {
    const fleetAddress = fleetAddresses[i]

    const roleName = generateContractSpecificRole(role, fleetAddress)
    if (roleName == roleHash) {
      return fleetAddress
    }
  }
  return null
}

// Result of decoding a contract-specific role against a set of rounds-vault
// addresses: the human-readable role name and the matched target address.
export class RoundsVaultRoleMatch {
  name: string
  target: string
  constructor(name: string, target: string) {
    this.name = name
    this.target = target
  }
}

// Rounds vaults carry KEEPER (granted to the keeper EOA) and OPERATOR (granted
// to the fleet) contract-specific roles. Given a role hash and the candidate
// rounds-vault addresses, return the decoded name + target, or null if the hash
// matches none of them. CURATOR does not apply to rounds vaults.
export function matchRoundsVaultRole(
  roleHash: string,
  roundsVaultAddresses: string[],
): RoundsVaultRoleMatch | null {
  const keeper = getContractSpecificRoleName(
    roleHash,
    ContractSpecificRole.KEEPER_ROLE,
    roundsVaultAddresses,
  )
  if (keeper) {
    return new RoundsVaultRoleMatch(RoleName.KEEPER_ROLE, keeper)
  }
  const operator = getContractSpecificRoleName(
    roleHash,
    ContractSpecificRole.OPERATOR_ROLE,
    roundsVaultAddresses,
  )
  if (operator) {
    return new RoundsVaultRoleMatch(RoleName.OPERATOR_ROLE, operator)
  }
  return null
}
