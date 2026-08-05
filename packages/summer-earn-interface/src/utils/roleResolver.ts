import { encodePacked, keccak256, toHex } from 'viem'

import arbitrumDeployed from '../config/deployment/deployed/arbitrum.json'
import baseDeployed from '../config/deployment/deployed/base.json'
import hyperliquidDeployed from '../config/deployment/deployed/hyperliquid.json'
import mainnetDeployed from '../config/deployment/deployed/mainnet.json'
import sepoliaDeployed from '../config/deployment/deployed/sepolia.json'
import sonicDeployed from '../config/deployment/deployed/sonic.json'
import indexConfig from '../config/deployment/index.json'

const GLOBAL_ROLES = [
  'DEFAULT_ADMIN_ROLE',
  'GUARDIAN_ROLE',
  'SUPER_KEEPER_ROLE',
  'DECAY_CONTROLLER_ROLE',
  'ADMIRALS_QUARTERS_ROLE',
  'FOUNDATION_ROLE',
  'GOVERNOR_ROLE',
  'WHITELIST_MANAGER_ROLE',
  'WHITELIST_ROLE',
  'EXECUTOR_ROLE',
  'PROPOSER_ROLE',
  'CANCELLER_ROLE',
]

const GLOBAL_ROLE_HASH_MAP: Record<string, string> = {
  '0x0000000000000000000000000000000000000000000000000000000000000000': 'DEFAULT_ADMIN_ROLE',
}

for (const name of GLOBAL_ROLES) {
  if (name === 'DEFAULT_ADMIN_ROLE') continue
  const hash = keccak256(toHex(name)).toLowerCase()
  GLOBAL_ROLE_HASH_MAP[hash] = name
}

export enum ContractSpecificRole {
  CURATOR_ROLE = 0,
  KEEPER_ROLE = 1,
  COMMANDER_ROLE = 2,
  OPERATOR_ROLE = 3,
}

const CONTRACT_SPECIFIC_ROLE_NAMES: Record<number, string> = {
  [ContractSpecificRole.CURATOR_ROLE]: 'CURATOR_ROLE',
  [ContractSpecificRole.KEEPER_ROLE]: 'KEEPER_ROLE',
  [ContractSpecificRole.COMMANDER_ROLE]: 'COMMANDER_ROLE',
  [ContractSpecificRole.OPERATOR_ROLE]: 'OPERATOR_ROLE',
}

const deployedConfigs: Record<string, unknown> = {
  mainnet: mainnetDeployed,
  base: baseDeployed,
  arbitrum: arbitrumDeployed,
  sonic: sonicDeployed,
  hyperliquid: hyperliquidDeployed,
  sepolia: sepoliaDeployed,
}

// Map ChainId (numeric string) to config chain name
function getChainName(chainId: string): string {
  const chainIdMap: Record<string, string> = {
    '1': 'mainnet',
    '42161': 'arbitrum',
    '8453': 'base',
    '146': 'sonic',
    '999': 'hyperliquid',
    '11155111': 'sepolia',
  }
  return chainIdMap[chainId] || chainId
}

const candidateAddressCache = new Map<string, Array<{ address: string; label?: string }>>()

export function getCandidateAddressesForChain(
  chainId: string,
): Array<{ address: string; label?: string }> {
  if (candidateAddressCache.has(chainId)) {
    return candidateAddressCache.get(chainId)!
  }

  const chainName = getChainName(chainId)
  const chainData = (indexConfig as Record<string, unknown>)[chainName]
  const deployedData = deployedConfigs[chainName]

  const list: Array<{ address: string; label?: string }> = []
  const seen = new Set<string>()

  const extract = (obj: unknown, prefix = '') => {
    if (!obj || typeof obj !== 'object') return
    for (const [key, val] of Object.entries(obj)) {
      const label = prefix ? `${prefix}.${key}` : key
      if (typeof val === 'string' && val.startsWith('0x') && val.length === 42) {
        const lower = val.toLowerCase()
        if (!seen.has(lower)) {
          seen.add(lower)
          list.push({ address: lower, label })
        }
      } else if (typeof val === 'object' && val !== null) {
        if ('address' in val && typeof val.address === 'string' && val.address.startsWith('0x')) {
          const lower = (val.address as string).toLowerCase()
          if (!seen.has(lower)) {
            seen.add(lower)
            list.push({ address: lower, label })
          }
        } else {
          extract(val, label)
        }
      }
    }
  }

  if (chainData) extract(chainData)
  if (deployedData) extract(deployedData)

  candidateAddressCache.set(chainId, list)
  return list
}

export function resolveRole(
  role: { name: string; targetContract?: string },
  chainId?: string,
): { name: string; targetContract?: string; resolved: boolean } {
  const roleNameOrHash = role.name

  // If name doesn't start with "0x", it's already resolved
  if (!roleNameOrHash.startsWith('0x')) {
    return { name: roleNameOrHash, targetContract: role.targetContract, resolved: true }
  }

  const normHash = roleNameOrHash.toLowerCase()

  // 1. Check global named roles
  if (GLOBAL_ROLE_HASH_MAP[normHash]) {
    return {
      name: GLOBAL_ROLE_HASH_MAP[normHash],
      targetContract: role.targetContract,
      resolved: true,
    }
  }

  // 2. Check if targetContract is provided and non-zero
  const target = role.targetContract?.toLowerCase()
  const isTargetValid =
    target && target !== '0x0000000000000000000000000000000000000000' && target.length === 42

  if (isTargetValid) {
    for (const [enumValStr, roleName] of Object.entries(CONTRACT_SPECIFIC_ROLE_NAMES)) {
      const enumVal = Number(enumValStr)
      const computed = keccak256(
        encodePacked(['uint8', 'address'], [enumVal, target as `0x${string}`]),
      ).toLowerCase()

      if (computed === normHash) {
        return { name: roleName, targetContract: target, resolved: true }
      }
    }
  }

  // 3. Fallback: Search candidate addresses for this chain
  if (chainId) {
    const candidates = getCandidateAddressesForChain(chainId)
    for (const candidate of candidates) {
      const candAddr = candidate.address as `0x${string}`
      for (const [enumValStr, roleName] of Object.entries(CONTRACT_SPECIFIC_ROLE_NAMES)) {
        const enumVal = Number(enumValStr)
        const computed = keccak256(
          encodePacked(['uint8', 'address'], [enumVal, candAddr]),
        ).toLowerCase()

        if (computed === normHash) {
          return { name: roleName, targetContract: candAddr, resolved: true }
        }
      }
    }
  }

  // Could not resolve
  return { name: roleNameOrHash, targetContract: role.targetContract, resolved: false }
}
