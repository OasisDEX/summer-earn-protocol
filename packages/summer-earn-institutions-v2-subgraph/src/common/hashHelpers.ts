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

// A contract-specific role to look for: the enum used for hashing plus the
// human-readable name stored when it matches.
export class ContractSpecificRoleSpec {
  role: ContractSpecificRole
  name: string
  constructor(role: ContractSpecificRole, name: string) {
    this.role = role
    this.name = name
  }
}

// Decoded result: the role name and the matched target contract address.
export class ContractSpecificRoleMatch {
  name: string
  target: string
  constructor(name: string, target: string) {
    this.name = name
    this.target = target
  }
}

// FleetCommanders can hold CURATOR/KEEPER/OPERATOR. Rounds vaults hold KEEPER
// (granted to the keeper EOA) and OPERATOR (granted to the fleet); CURATOR does
// not apply to them.
export const FLEET_ROLE_SPECS: ContractSpecificRoleSpec[] = [
  new ContractSpecificRoleSpec(ContractSpecificRole.CURATOR_ROLE, RoleName.CURATOR_ROLE),
  new ContractSpecificRoleSpec(ContractSpecificRole.KEEPER_ROLE, RoleName.KEEPER_ROLE),
  new ContractSpecificRoleSpec(ContractSpecificRole.OPERATOR_ROLE, RoleName.OPERATOR_ROLE),
]

export const ROUNDS_VAULT_ROLE_SPECS: ContractSpecificRoleSpec[] = [
  new ContractSpecificRoleSpec(ContractSpecificRole.KEEPER_ROLE, RoleName.KEEPER_ROLE),
  new ContractSpecificRoleSpec(ContractSpecificRole.OPERATOR_ROLE, RoleName.OPERATOR_ROLE),
]

// Single matcher shared by the role-grant handler (fleet + rounds vault) and the
// registry backfill: try each role spec against the candidate addresses and
// return the first exact hash match, or null. A role hash matches at most one
// (role, target), so the first hit is the answer.
export function matchContractSpecificRole(
  roleHash: string,
  addresses: string[],
  specs: ContractSpecificRoleSpec[],
): ContractSpecificRoleMatch | null {
  for (let i = 0; i < specs.length; i++) {
    const spec = specs[i]
    const target = getContractSpecificRoleName(roleHash, spec.role, addresses)
    if (target) {
      return new ContractSpecificRoleMatch(spec.name, target)
    }
  }
  return null
}
