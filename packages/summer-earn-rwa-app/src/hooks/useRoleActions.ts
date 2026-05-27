'use client'

import { useQueryClient } from '@tanstack/react-query'

import { protocolAccessManagerAbi } from '@/abis/ProtocolAccessManager'
import { protocolAccessManagerV2Abi } from '@/abis/ProtocolAccessManagerV2'
import { useTxToast } from '@/hooks/useTxToast'
import {
  ADMIRALS_QUARTERS_ROLE,
  DECAY_CONTROLLER_ROLE,
  FOUNDATION_ROLE,
  generateContractSpecificRole,
  GOVERNOR_ROLE,
  GUARDIAN_ROLE,
  SUPER_KEEPER_ROLE,
  WHITELIST_MANAGER_ROLE,
} from '@/lib/access/roleHashes'
import type { ChainId } from '@/types/chain'

// ProtocolAccessManager (and V2) inherit LimitedAccessControl, which disables
// OZ AccessControl's grantRole/revokeRole. The contract instead exposes
// typed wrappers gated by onlyGovernor / onlyRole(GOVERNOR_ROLE). This hook
// dispatches to the right wrapper for each role kind.
//
// V2 extends V1, so the V1 wrappers are still callable on a V2-deployed PAM
// — we just hand viem the V1 ABI for those entries.
export type GrantableRole =
  | { kind: 'GOVERNOR' }
  | { kind: 'SUPER_KEEPER' }
  | { kind: 'GUARDIAN' }
  | { kind: 'DECAY_CONTROLLER' }
  | { kind: 'ADMIRALS_QUARTERS' }
  | { kind: 'FOUNDATION' }
  | { kind: 'WHITELIST_MANAGER' }
  | { kind: 'KEEPER'; fleet: `0x${string}` }
  | { kind: 'CURATOR'; fleet: `0x${string}` }
  | { kind: 'COMMANDER'; ark: `0x${string}` }
  | { kind: 'OPERATOR'; fleet: `0x${string}` }

/** Compute the bytes32 hash a contract call would derive for this role. */
export function roleHash(role: GrantableRole): `0x${string}` {
  switch (role.kind) {
    case 'GOVERNOR':
      return GOVERNOR_ROLE
    case 'SUPER_KEEPER':
      return SUPER_KEEPER_ROLE
    case 'GUARDIAN':
      return GUARDIAN_ROLE
    case 'DECAY_CONTROLLER':
      return DECAY_CONTROLLER_ROLE
    case 'ADMIRALS_QUARTERS':
      return ADMIRALS_QUARTERS_ROLE
    case 'FOUNDATION':
      return FOUNDATION_ROLE
    case 'WHITELIST_MANAGER':
      return WHITELIST_MANAGER_ROLE
    case 'KEEPER':
      return generateContractSpecificRole('KEEPER_ROLE', role.fleet)
    case 'CURATOR':
      return generateContractSpecificRole('CURATOR_ROLE', role.fleet)
    case 'COMMANDER':
      return generateContractSpecificRole('COMMANDER_ROLE', role.ark)
    case 'OPERATOR':
      return generateContractSpecificRole('OPERATOR_ROLE', role.fleet)
  }
}

type Call =
  | {
      abi: typeof protocolAccessManagerAbi
      functionName:
        | 'grantGovernorRole'
        | 'revokeGovernorRole'
        | 'grantSuperKeeperRole'
        | 'revokeSuperKeeperRole'
        | 'grantGuardianRole'
        | 'revokeGuardianRole'
        | 'grantDecayControllerRole'
        | 'revokeDecayControllerRole'
        | 'grantAdmiralsQuartersRole'
        | 'revokeAdmiralsQuartersRole'
        | 'grantFoundationRole'
        | 'revokeFoundationRole'
      args: [`0x${string}`]
    }
  | {
      abi: typeof protocolAccessManagerAbi
      functionName:
        | 'grantKeeperRole'
        | 'revokeKeeperRole'
        | 'grantCuratorRole'
        | 'revokeCuratorRole'
        | 'grantCommanderRole'
        | 'revokeCommanderRole'
      args: [`0x${string}`, `0x${string}`]
    }
  | {
      abi: typeof protocolAccessManagerV2Abi
      functionName: 'grantWhitelistManagerRole' | 'revokeWhitelistManagerRole'
      args: [`0x${string}`]
    }
  | {
      abi: typeof protocolAccessManagerV2Abi
      functionName: 'grantOperatorRole' | 'revokeOperatorRole'
      args: [`0x${string}`, `0x${string}`]
    }

function grantCall(role: GrantableRole, account: `0x${string}`): Call {
  switch (role.kind) {
    case 'GOVERNOR':
      return { abi: protocolAccessManagerAbi, functionName: 'grantGovernorRole', args: [account] }
    case 'SUPER_KEEPER':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'grantSuperKeeperRole',
        args: [account],
      }
    case 'GUARDIAN':
      return { abi: protocolAccessManagerAbi, functionName: 'grantGuardianRole', args: [account] }
    case 'DECAY_CONTROLLER':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'grantDecayControllerRole',
        args: [account],
      }
    case 'ADMIRALS_QUARTERS':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'grantAdmiralsQuartersRole',
        args: [account],
      }
    case 'FOUNDATION':
      return { abi: protocolAccessManagerAbi, functionName: 'grantFoundationRole', args: [account] }
    case 'WHITELIST_MANAGER':
      return {
        abi: protocolAccessManagerV2Abi,
        functionName: 'grantWhitelistManagerRole',
        args: [account],
      }
    case 'KEEPER':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'grantKeeperRole',
        args: [role.fleet, account],
      }
    case 'CURATOR':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'grantCuratorRole',
        args: [role.fleet, account],
      }
    case 'COMMANDER':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'grantCommanderRole',
        args: [role.ark, account],
      }
    case 'OPERATOR':
      return {
        abi: protocolAccessManagerV2Abi,
        functionName: 'grantOperatorRole',
        args: [role.fleet, account],
      }
  }
}

function revokeCall(role: GrantableRole, account: `0x${string}`): Call {
  switch (role.kind) {
    case 'GOVERNOR':
      return { abi: protocolAccessManagerAbi, functionName: 'revokeGovernorRole', args: [account] }
    case 'SUPER_KEEPER':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'revokeSuperKeeperRole',
        args: [account],
      }
    case 'GUARDIAN':
      return { abi: protocolAccessManagerAbi, functionName: 'revokeGuardianRole', args: [account] }
    case 'DECAY_CONTROLLER':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'revokeDecayControllerRole',
        args: [account],
      }
    case 'ADMIRALS_QUARTERS':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'revokeAdmiralsQuartersRole',
        args: [account],
      }
    case 'FOUNDATION':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'revokeFoundationRole',
        args: [account],
      }
    case 'WHITELIST_MANAGER':
      return {
        abi: protocolAccessManagerV2Abi,
        functionName: 'revokeWhitelistManagerRole',
        args: [account],
      }
    case 'KEEPER':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'revokeKeeperRole',
        args: [role.fleet, account],
      }
    case 'CURATOR':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'revokeCuratorRole',
        args: [role.fleet, account],
      }
    case 'COMMANDER':
      return {
        abi: protocolAccessManagerAbi,
        functionName: 'revokeCommanderRole',
        args: [role.ark, account],
      }
    case 'OPERATOR':
      return {
        abi: protocolAccessManagerV2Abi,
        functionName: 'revokeOperatorRole',
        args: [role.fleet, account],
      }
  }
}

interface UseRoleActionsProps {
  pamAddress: `0x${string}`
  chainId: ChainId
}

export function useRoleActions({ pamAddress, chainId }: UseRoleActionsProps) {
  const queryClient = useQueryClient()
  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['institution-roles'] })
    queryClient.invalidateQueries({ queryKey: ['access'] })
  }

  const grant = useTxToast({
    chainId,
    labels: {
      pending: 'Granting role…',
      success: 'Role granted',
      error: 'Grant failed',
    },
    onSuccess: invalidate,
  })

  const revoke = useTxToast({
    chainId,
    labels: {
      pending: 'Revoking role…',
      success: 'Role revoked',
      error: 'Revoke failed',
    },
    onSuccess: invalidate,
  })

  return {
    grant: (role: GrantableRole, account: `0x${string}`) => {
      grant.beginToast()
      const call = grantCall(role, account)
      // viem's writeContractAsync types are sharper than the dispatcher union
      // we can express here; cast at the boundary.
      return grant.writeContractAsync({
        address: pamAddress,
        ...call,
      } as never)
    },
    revoke: (role: GrantableRole, account: `0x${string}`) => {
      revoke.beginToast()
      const call = revokeCall(role, account)
      return revoke.writeContractAsync({
        address: pamAddress,
        ...call,
      } as never)
    },
    pending: {
      grant: grant.isWriting || grant.isMining,
      revoke: revoke.isWriting || revoke.isMining,
    },
  }
}
