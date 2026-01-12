import { Address } from '@graphprotocol/graph-ts'

export namespace RoleAction {
  export const GRANT_ROLE = 'GRANT_ROLE'
  export const REVOKE_ROLE = 'REVOKE_ROLE'
}

export namespace RoleName {
  export const WHITELIST_ROLE = 'WHITELIST_ROLE'
  export const COMMANDER_ROLE = 'COMMANDER_ROLE'
  export const CURATOR_ROLE = 'CURATOR_ROLE'
  export const KEEPER_ROLE = 'KEEPER_ROLE'
  export const GOVERNOR_ROLE = 'GOVERNOR_ROLE'
  export const SUPER_KEEPER_ROLE = 'SUPER_KEEPER_ROLE'
  export const GUARDIAN_ROLE = 'GUARDIAN_ROLE'
  export const DECAY_CONTROLLER_ROLE = 'DECAY_CONTROLLER_ROLE'
  export const ADMIRALS_QUARTERS_ROLE = 'ADMIRALS_QUARTERS_ROLE'
  export const FOUNDATION_ROLE = 'FOUNDATION_ROLE'
  export const PROPOSER_ROLE = 'PROPOSER_ROLE'
  export const EXECUTOR_ROLE = 'EXECUTOR_ROLE'
  export const CANCELLER_ROLE = 'CANCELLER_ROLE'
}

// enum used to compute the contract specific role name
// Solidity: keccak256(abi.encodePacked(uint8(role), address(contractAddress)))
export enum ContractSpecificRole {
  CURATOR_ROLE,
  KEEPER_ROLE,
  COMMANDER_ROLE,
}

export const ADDRESS_ZERO = Address.fromString('0x0000000000000000000000000000000000000000')
