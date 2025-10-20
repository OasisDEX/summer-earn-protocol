import { Address, ByteArray, Bytes, crypto, log } from '@graphprotocol/graph-ts'
import { ProtocolAccessManager } from '../../generated/InstitutionalVaultRegistry/ProtocolAccessManager'
export class ROLES {
  static GUARDIAN_ROLE: string = 'GUARDIAN_ROLE'
  static SUPER_KEEPER_ROLE: string = 'SUPER_KEEPER_ROLE'
  static DECAY_CONTROLLER_ROLE: string = 'DECAY_CONTROLLER_ROLE'
  static ADMIRALS_QUARTERS_ROLE: string = 'ADMIRALS_QUARTERS_ROLE'
  static FOUNDATION_ROLE: string = 'FOUNDATION_ROLE'
  static GOVERNOR_ROLE: string = 'GOVERNOR_ROLE'
}

function getHash(name: string): string {
  return crypto.keccak256(ByteArray.fromUTF8(name)).toHexString()
}

export const ROLE_MAP = new Map<string, string>()
  .set(getHash(ROLES.GUARDIAN_ROLE), 'GUARDIAN_ROLE')
  .set(getHash(ROLES.SUPER_KEEPER_ROLE), 'SUPER_KEEPER_ROLE')
  .set(getHash(ROLES.DECAY_CONTROLLER_ROLE), 'DECAY_CONTROLLER_ROLE')
  .set(getHash(ROLES.ADMIRALS_QUARTERS_ROLE), 'ADMIRALS_QUARTERS_ROLE')
  .set(getHash(ROLES.FOUNDATION_ROLE), 'FOUNDATION_ROLE')
  .set(getHash(ROLES.GOVERNOR_ROLE), 'GOVERNOR_ROLE')

export enum ContractSpecificRole {
  CURATOR_ROLE,
  KEEPER_ROLE,
  COMMANDER_ROLE,
}

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
  const hash = crypto.keccak256(packed).toHexString()
  log.error(' role: {} address: {}, hash: {}', [role.toString(), contractAddress, hash])
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
    log.error('role hash: {}', [roleHash])
    const roleName = generateContractSpecificRole(role, fleetAddress)
    if (roleName == roleHash) {
      return fleetAddress
    }
  }
  return null
}
