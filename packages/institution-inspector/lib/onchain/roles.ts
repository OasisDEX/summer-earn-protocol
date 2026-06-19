import { type Hex, encodePacked, keccak256, stringToHex, toBytes } from 'viem'

// Global role identifiers: keccak256 of the role name (see ProtocolAccessManager.sol).
export const GLOBAL_ROLES: Record<string, Hex> = {
  GOVERNOR_ROLE: keccak256(toBytes('GOVERNOR_ROLE')),
  GUARDIAN_ROLE: keccak256(toBytes('GUARDIAN_ROLE')),
  SUPER_KEEPER_ROLE: keccak256(toBytes('SUPER_KEEPER_ROLE')),
  WHITELIST_MANAGER_ROLE: keccak256(toBytes('WHITELIST_MANAGER_ROLE')),
}

// ContractSpecificRoles enum (access-contracts): CURATOR=0, KEEPER=1, COMMANDER=2, OPERATOR=3.
export const CONTRACT_ROLE_ENUM: Record<string, number> = {
  CURATOR_ROLE: 0,
  KEEPER_ROLE: 1,
  COMMANDER_ROLE: 2,
  OPERATOR_ROLE: 3,
}

/** PAM.generateRole(role, target) = keccak256(abi.encodePacked(uint8(role), target)). */
export function generateRole(roleEnum: number, target: Hex): Hex {
  return keccak256(encodePacked(['uint8', 'address'], [roleEnum, target]))
}

/** bytes32 institution id = raw right-padded UTF-8 cast (matches getBytes32InstitutionId). */
export function institutionBytes32(name: string): Hex {
  return stringToHex(name, { size: 32 })
}

/**
 * Resolve the on-chain role hash for a config-declared role edge.
 * Returns null when the role can't be resolved (so we leave it unverified rather than wrong).
 */
export function resolveRoleHash(role: string, contractTarget?: Hex): Hex | null {
  if (GLOBAL_ROLES[role]) return GLOBAL_ROLES[role]
  if (role in CONTRACT_ROLE_ENUM && contractTarget)
    return generateRole(CONTRACT_ROLE_ENUM[role], contractTarget)
  return null
}
