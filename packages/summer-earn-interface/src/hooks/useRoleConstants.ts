import { useReadContract } from 'wagmi'

import { protocolAccessManagerAbi } from '../abis/ProtocolAccessManager'
import type { GlobalRole } from '../types'

interface UseRoleConstantsProps {
  contractAddress: string
}

export function useRoleConstants({ contractAddress }: UseRoleConstantsProps) {
  const { data: governorRole } = useReadContract({
    abi: protocolAccessManagerAbi,
    address: contractAddress as `0x${string}`,
    functionName: 'GOVERNOR_ROLE',
    query: {
      staleTime: Infinity, // Role constants never change
    },
  })

  const { data: superKeeperRole } = useReadContract({
    abi: protocolAccessManagerAbi,
    address: contractAddress as `0x${string}`,
    functionName: 'SUPER_KEEPER_ROLE',
    query: {
      staleTime: Infinity,
    },
  })

  const { data: guardianRole } = useReadContract({
    abi: protocolAccessManagerAbi,
    address: contractAddress as `0x${string}`,
    functionName: 'GUARDIAN_ROLE',
    query: {
      staleTime: Infinity,
    },
  })

  const { data: decayControllerRole } = useReadContract({
    abi: protocolAccessManagerAbi,
    address: contractAddress as `0x${string}`,
    functionName: 'DECAY_CONTROLLER_ROLE',
    query: {
      staleTime: Infinity,
    },
  })

  const { data: admiralsQuartersRole } = useReadContract({
    abi: protocolAccessManagerAbi,
    address: contractAddress as `0x${string}`,
    functionName: 'ADMIRALS_QUARTERS_ROLE',
    query: {
      staleTime: Infinity,
    },
  })

  const { data: foundationRole } = useReadContract({
    abi: protocolAccessManagerAbi,
    address: contractAddress as `0x${string}`,
    functionName: 'FOUNDATION_ROLE',
    query: {
      staleTime: Infinity,
    },
  })

  const getRoleHash = (role: GlobalRole): `0x${string}` | undefined => {
    switch (role) {
      case 'GOVERNOR_ROLE':
        return governorRole
      case 'SUPER_KEEPER_ROLE':
        return superKeeperRole
      case 'GUARDIAN_ROLE':
        return guardianRole
      case 'DECAY_CONTROLLER_ROLE':
        return decayControllerRole
      case 'ADMIRALS_QUARTERS_ROLE':
        return admiralsQuartersRole
      case 'FOUNDATION_ROLE':
        return foundationRole
      default:
        return undefined
    }
  }

  return {
    getRoleHash,
    roleConstants: {
      GOVERNOR_ROLE: governorRole,
      SUPER_KEEPER_ROLE: superKeeperRole,
      GUARDIAN_ROLE: guardianRole,
      DECAY_CONTROLLER_ROLE: decayControllerRole,
      ADMIRALS_QUARTERS_ROLE: admiralsQuartersRole,
      FOUNDATION_ROLE: foundationRole,
    },
  }
}
