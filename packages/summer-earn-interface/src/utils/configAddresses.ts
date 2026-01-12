import type { ChainId } from '../types'

// This will be populated by synced config files
// The config files are synced from deployment/config/index.json
// via the sync-config script

interface ConfigAddresses {
  protocolAccessManager?: string
  harborCommand?: string
  summerGovernor?: string
  summerGovernorV2?: string
  timelock?: string
  [key: string]: string | undefined
}

let configCache: Record<ChainId, ConfigAddresses> | null = null

// Map ChainId (numeric string) to config chain name
function getChainName(chainId: ChainId): string {
  const chainIdMap: Record<ChainId, string> = {
    '1': 'mainnet',
    '42161': 'arbitrum',
    '8453': 'base',
    '146': 'sonic',
    '999': 'hyperliquid',
  }
  return chainIdMap[chainId] || chainId
}

// Try to load config - this will work if the file exists (after running sync-config)
// If not, we'll return empty addresses gracefully
let configData: any = null
try {
  // @ts-ignore - dynamic import path, file may not exist
  configData = require('../config/deployment/index.json')
} catch {
  // Config file doesn't exist yet - that's okay, we'll return empty labels
  configData = null
}

function loadConfigForChain(chainId: ChainId): ConfigAddresses {
  if (configCache && configCache[chainId]) {
    return configCache[chainId]
  }

  if (!configData) {
    return {}
  }

  try {
    const chainName = getChainName(chainId)
    const foundation = configData[chainName]?.common?.foundation
    const chainConfig = configData[chainName]?.deployedContracts

    if (!chainConfig) {
      return {}
    }

    const addresses: ConfigAddresses = {}

    // Extract addresses from config structure
    // Prefer govV2 over gov for protocolAccessManager and timelock
    if (chainConfig.govV2?.protocolAccessManager?.address) {
      addresses.protocolAccessManager = chainConfig.govV2.protocolAccessManager.address
    } else if (chainConfig.gov?.protocolAccessManager?.address) {
      addresses.protocolAccessManager = chainConfig.gov.protocolAccessManager.address
    }

    if (chainConfig.govV2?.timelock?.address) {
      addresses.timelock = chainConfig.govV2.timelock.address
    } else if (chainConfig.gov?.timelock?.address) {
      addresses.timelock = chainConfig.gov.timelock.address
    }

    if (chainConfig.core?.harborCommand?.address) {
      addresses.harborCommand = chainConfig.core.harborCommand.address
    }

    if (chainConfig.govV2?.summerGovernor?.address) {
      addresses.summerGovernorV2 = chainConfig.govV2.summerGovernor.address
    }

    if (chainConfig.gov?.summerGovernor?.address) {
      addresses.summerGovernor = chainConfig.gov.summerGovernor.address
    }

    if (foundation) {
      addresses.foundation = foundation
    }
    if (!configCache) {
      configCache = {} as Record<ChainId, ConfigAddresses>
    }
    configCache[chainId] = addresses

    return addresses
  } catch (error) {
    console.warn(`Failed to load config for chain ${chainId}:`, error)
    return {}
  }
}

export function getAddressLabel(chainId: ChainId, address: string): string | null {
  const addresses = loadConfigForChain(chainId)
  const normalizedAddress = address.toLowerCase()

  for (const [key, value] of Object.entries(addresses)) {
    if (value?.toLowerCase() === normalizedAddress) {
      // Convert camelCase to readable label
      return key
        .replace(/([A-Z])/g, ' $1')
        .replace(/^./, (str) => str.toUpperCase())
        .trim()
    }
  }

  return null
}

export function getAllAddressLabels(chainId: ChainId): Record<string, string> {
  const addresses = loadConfigForChain(chainId)
  const labels: Record<string, string> = {}

  for (const [key, value] of Object.entries(addresses)) {
    if (value) {
      const label = key
        .replace(/([A-Z])/g, ' $1')
        .replace(/^./, (str) => str.toUpperCase())
        .trim()
      labels[value.toLowerCase()] = label
    }
  }

  return labels
}
