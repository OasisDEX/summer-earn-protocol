'use client'

import { useReadContracts } from 'wagmi'

import { protocolAccessManagerAbi } from '@/abis/ProtocolAccessManager'
import { protocolAccessManagerV2Abi } from '@/abis/ProtocolAccessManagerV2'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import {
  generateContractSpecificRole,
  GOVERNOR_ROLE,
  SUPER_KEEPER_ROLE,
  WHITELIST_MANAGER_ROLE,
} from '@/lib/access/roleHashes'

interface UseAccessProps {
  institution: Pick<Institution, 'protocolAccessManager' | 'chainId'>
  fleet: Pick<InstitutionFleet, 'fleetCommander' | 'roundsVaultInput' | 'roundsVaultOutput'>
  account?: `0x${string}`
}

// Composed role/whitelist check the admin tabs use to grey out controls the
// caller isn't allowed to invoke. All reads go through the institution's PAM.
export function useAccess({ institution, fleet, account }: UseAccessProps) {
  const pam = institution.protocolAccessManager
  const fleetAddr = fleet.fleetCommander
  const inputRv = fleet.roundsVaultInput
  const outputRv = fleet.roundsVaultOutput

  const keeperFleetRole = generateContractSpecificRole('KEEPER_ROLE', fleetAddr)
  const curatorFleetRole = generateContractSpecificRole('CURATOR_ROLE', fleetAddr)
  const keeperInputRole = inputRv ? generateContractSpecificRole('KEEPER_ROLE', inputRv) : undefined
  const keeperOutputRole = outputRv
    ? generateContractSpecificRole('KEEPER_ROLE', outputRv)
    : undefined

  const reads = useReadContracts({
    contracts: account
      ? [
          {
            address: pam,
            abi: protocolAccessManagerAbi,
            functionName: 'hasRole',
            args: [GOVERNOR_ROLE, account],
          },
          {
            address: pam,
            abi: protocolAccessManagerAbi,
            functionName: 'hasRole',
            args: [SUPER_KEEPER_ROLE, account],
          },
          {
            address: pam,
            abi: protocolAccessManagerAbi,
            functionName: 'hasRole',
            args: [WHITELIST_MANAGER_ROLE, account],
          },
          {
            address: pam,
            abi: protocolAccessManagerAbi,
            functionName: 'hasRole',
            args: [keeperFleetRole, account],
          },
          {
            address: pam,
            abi: protocolAccessManagerAbi,
            functionName: 'hasRole',
            args: [curatorFleetRole, account],
          },
          ...(keeperInputRole
            ? [
                {
                  address: pam,
                  abi: protocolAccessManagerAbi,
                  functionName: 'hasRole' as const,
                  args: [keeperInputRole, account] as const,
                },
              ]
            : []),
          ...(keeperOutputRole
            ? [
                {
                  address: pam,
                  abi: protocolAccessManagerAbi,
                  functionName: 'hasRole' as const,
                  args: [keeperOutputRole, account] as const,
                },
              ]
            : []),
          {
            address: pam,
            abi: protocolAccessManagerV2Abi,
            functionName: 'isWhitelisted',
            args: [fleetAddr, account],
          },
          {
            address: pam,
            abi: protocolAccessManagerV2Abi,
            functionName: 'isWhitelistOpen',
            args: [fleetAddr],
          },
        ]
      : [],
    query: { enabled: !!account, staleTime: 30_000 },
  })

  const results = reads.data ?? []
  let i = 0
  const isGovernor = results[i++]?.result as boolean | undefined
  const isSuperKeeper = results[i++]?.result as boolean | undefined
  const isWhitelistManager = results[i++]?.result as boolean | undefined
  const isFleetKeeper = results[i++]?.result as boolean | undefined
  const isCurator = results[i++]?.result as boolean | undefined
  const isInputKeeper = keeperInputRole ? (results[i++]?.result as boolean | undefined) : undefined
  const isOutputKeeper = keeperOutputRole
    ? (results[i++]?.result as boolean | undefined)
    : undefined
  const explicitlyWhitelisted = results[i++]?.result as boolean | undefined
  const whitelistOpen = results[i]?.result as boolean | undefined

  const canKeeperFleet = !!(isSuperKeeper || isFleetKeeper)
  const canKeeperInput = !!(isSuperKeeper || isInputKeeper)
  const canKeeperOutput = !!(isSuperKeeper || isOutputKeeper)

  return {
    isGovernor: !!isGovernor,
    isSuperKeeper: !!isSuperKeeper,
    isWhitelistManager: !!isWhitelistManager,
    isCurator: !!isCurator,
    canKeeperFleet,
    canKeeperInput,
    canKeeperOutput,
    canRebalance: canKeeperFleet || isCurator || false,
    isDepositorWhitelisted: !!(whitelistOpen || explicitlyWhitelisted),
    isWhitelistOpen: !!whitelistOpen,
    loading: reads.isLoading,
    error: reads.error as Error | null,
    refetch: reads.refetch,
  }
}
