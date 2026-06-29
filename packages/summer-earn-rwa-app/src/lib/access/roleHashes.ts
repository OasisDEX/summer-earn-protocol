import { encodePacked, keccak256, toBytes } from 'viem'

// Mirror packages/access-contracts/src/contracts/ProtocolAccessManager.sol
// constants and the generateContractSpecificRole helper used on chain.

export const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))
export const SUPER_KEEPER_ROLE = keccak256(toBytes('SUPER_KEEPER_ROLE'))
export const GUARDIAN_ROLE = keccak256(toBytes('GUARDIAN_ROLE'))
export const DECAY_CONTROLLER_ROLE = keccak256(toBytes('DECAY_CONTROLLER_ROLE'))
export const ADMIRALS_QUARTERS_ROLE = keccak256(toBytes('ADMIRALS_QUARTERS_ROLE'))
export const FOUNDATION_ROLE = keccak256(toBytes('FOUNDATION_ROLE'))
export const WHITELIST_MANAGER_ROLE = keccak256(toBytes('WHITELIST_MANAGER_ROLE'))
export const DEFAULT_ADMIN_ROLE =
  '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`

export type ContractSpecificRoleName =
  | 'CURATOR_ROLE'
  | 'KEEPER_ROLE'
  | 'COMMANDER_ROLE'
  | 'OPERATOR_ROLE'

// On-chain, contract-specific roles are hashed from the ContractSpecificRoles
// ENUM (encoded as its uint8 index), NOT the role's string name — see
// generateRole() and the enum order in IProtocolAccessManager.sol. Hashing the
// string here produced a role nobody holds, so legitimately-granted KEEPER /
// CURATOR holders read as unauthorised (only the static SUPER_KEEPER_ROLE worked).
const CONTRACT_SPECIFIC_ROLE_INDEX: Record<ContractSpecificRoleName, number> = {
  CURATOR_ROLE: 0,
  KEEPER_ROLE: 1,
  COMMANDER_ROLE: 2,
  OPERATOR_ROLE: 3,
}

export function generateContractSpecificRole(
  roleName: ContractSpecificRoleName,
  target: `0x${string}`,
): `0x${string}` {
  return keccak256(
    encodePacked(['uint8', 'address'], [CONTRACT_SPECIFIC_ROLE_INDEX[roleName], target]),
  )
}
