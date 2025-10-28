import fs from 'fs'
import path from 'path'

export interface CrossChainConfig {
  fleetName: string
  sourceChainId: number
  hubFleetAddress: string
  hubFleetName: string
  satelliteFleetName: string
  destinations: Array<{
    chainId: number
    name: string
    protocols: Array<{
      protocol: string
      fleetProxyAddress: string
      crossChainArkAddress: string
      satelliteFleetAddress: string
    }>
  }>
}

export function loadCrossChainConfig(fleetName: string): CrossChainConfig | null {
  const configPath = path.join(process.cwd(), 'config', 'cross-chain', `${fleetName}.json`)

  if (!fs.existsSync(configPath)) {
    return null
  }

  try {
    const raw = fs.readFileSync(configPath, 'utf8')
    const data = JSON.parse(raw) as CrossChainConfig
    return data
  } catch (error) {
    console.error(`Failed to load cross-chain config for ${fleetName}:`, error)
    return null
  }
}

export function listCrossChainConfigs(): string[] {
  const configDir = path.join(process.cwd(), 'config', 'cross-chain')

  if (!fs.existsSync(configDir)) {
    return []
  }

  return fs
    .readdirSync(configDir)
    .filter((file) => file.endsWith('.json'))
    .map((file) => file.replace('.json', ''))
    .sort()
}

export function saveCrossChainConfig(fleetName: string, config: CrossChainConfig): void {
  const configDir = path.join(process.cwd(), 'config', 'cross-chain')
  const configPath = path.join(configDir, `${fleetName}.json`)

  // Ensure directory exists
  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true })
  }

  fs.writeFileSync(configPath, JSON.stringify(config, null, 2))
}
