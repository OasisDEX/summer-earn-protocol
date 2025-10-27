import * as fs from 'fs'
import kleur from 'kleur'
import * as path from 'path'

export interface CrossChainProtocolConfig {
  protocol: string
  fleetProxyAddress: string | null
  crossChainArkAddress: string | null
}

export interface CrossChainDestination {
  chainId: number
  name: string
  protocols: CrossChainProtocolConfig[]
}

export interface CrossChainConfig {
  fleetName: string
  sourceChainId: number
  destinations: CrossChainDestination[]
}

const CONFIG_DIR = path.join(process.cwd(), 'config', 'cross-chain')

export function loadCrossChainConfig(fleetName: string): CrossChainConfig | null {
  const configPath = path.join(CONFIG_DIR, `${fleetName}.json`)
  if (!fs.existsSync(configPath)) {
    console.log(kleur.yellow(`No cross-chain config found for ${fleetName}`))
    return null
  }

  try {
    const configContent = fs.readFileSync(configPath, 'utf-8')
    return JSON.parse(configContent) as CrossChainConfig
  } catch (error) {
    console.error(kleur.red(`Error loading cross-chain config for ${fleetName}: ${error}`))
    return null
  }
}

export function saveCrossChainConfig(
  fleetName: string,
  updateData: {
    chainId?: number
    protocol?: string
    fleetProxyAddress?: string
    crossChainArkAddress?: string
    sourceChainId?: number
  },
): void {
  const configPath = path.join(CONFIG_DIR, `${fleetName}.json`)

  // Create directories if they don't exist
  if (!fs.existsSync(CONFIG_DIR)) {
    fs.mkdirSync(CONFIG_DIR, { recursive: true })
  }

  let config: CrossChainConfig

  // Load existing config or create a new one
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf-8')) as CrossChainConfig
  } else {
    config = {
      fleetName,
      sourceChainId: 0, // Will need to be set manually or by parameter
      destinations: [],
    }
  }

  // Update sourceChainId if provided
  if (updateData.sourceChainId) {
    config.sourceChainId = updateData.sourceChainId
  }

  // If chainId and protocol are provided, we need to update a specific protocol in a destination
  if (updateData.chainId && updateData.protocol) {
    // Find destination by chainId
    let destination = config.destinations.find((d) => d.chainId === updateData.chainId)

    // If destination doesn't exist, create it
    if (!destination) {
      destination = {
        chainId: updateData.chainId,
        name: `chain-${updateData.chainId}`, // Default name
        protocols: [],
      }
      config.destinations.push(destination)
    }

    // Find protocol in the destination
    let protocolConfig = destination.protocols.find((p) => p.protocol === updateData.protocol)

    // If protocol doesn't exist, create it
    if (!protocolConfig) {
      protocolConfig = {
        protocol: updateData.protocol,
        fleetProxyAddress: null,
        crossChainArkAddress: null,
      }
      destination.protocols.push(protocolConfig)
    }

    // Update the protocol configuration
    if (updateData.fleetProxyAddress) {
      protocolConfig.fleetProxyAddress = updateData.fleetProxyAddress
    }

    if (updateData.crossChainArkAddress) {
      protocolConfig.crossChainArkAddress = updateData.crossChainArkAddress
    }
  }

  // Write the updated config back to the file
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2))
  console.log(kleur.green(`Updated cross-chain config for ${fleetName}`))
}

// Helper function to find a specific protocol configuration
export function findProtocolConfig(
  config: CrossChainConfig,
  chainId: number,
  protocol: string,
): CrossChainProtocolConfig | null {
  const destination = config.destinations.find((d) => d.chainId === chainId)
  if (!destination) return null

  const protocolConfig = destination.protocols.find((p) => p.protocol === protocol)
  return protocolConfig || null
}
