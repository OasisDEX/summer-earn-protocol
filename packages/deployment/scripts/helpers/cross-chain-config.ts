import fs from 'fs'
import path from 'path'
import { Address } from 'viem'

interface CrossChainDeploymentConfig {
  fleetName: string
  fleetProxyAddress?: Address
  crossChainArkAddress?: Address
  sourceChainId?: number
  satelliteChainId?: number
  updated?: string // Timestamp for tracking when config was last updated
}

const CONFIG_DIR = path.join(__dirname, '../../deployments/cross-chain')
const CONFIG_FILE_EXTENSION = '.json'

/**
 * Ensures the config directory exists
 */
function ensureConfigDir() {
  if (!fs.existsSync(CONFIG_DIR)) {
    fs.mkdirSync(CONFIG_DIR, { recursive: true })
  }
}

/**
 * Gets the path to the config file for a specific fleet
 */
function getConfigPath(fleetName: string): string {
  return path.join(CONFIG_DIR, `${fleetName}${CONFIG_FILE_EXTENSION}`)
}

/**
 * Saves cross-chain deployment configuration for a specific fleet
 * @param fleetName Name of the fleet
 * @param config Configuration data to save
 */
export function saveCrossChainConfig(
  fleetName: string,
  config: Partial<CrossChainDeploymentConfig>,
): void {
  ensureConfigDir()

  const configPath = getConfigPath(fleetName)
  let existingConfig: CrossChainDeploymentConfig = { fleetName }

  // Read existing config if it exists
  if (fs.existsSync(configPath)) {
    const fileContent = fs.readFileSync(configPath, 'utf8')
    existingConfig = JSON.parse(fileContent) as CrossChainDeploymentConfig
  }

  // Merge new config with existing
  const updatedConfig: CrossChainDeploymentConfig = {
    ...existingConfig,
    ...config,
    updated: new Date().toISOString(),
  }

  // Write updated config to file
  fs.writeFileSync(configPath, JSON.stringify(updatedConfig, null, 2))
}

/**
 * Loads cross-chain deployment configuration for a specific fleet
 * @param fleetName Name of the fleet
 * @returns The configuration data or null if not found
 */
export function loadCrossChainConfig(fleetName: string): CrossChainDeploymentConfig | null {
  const configPath = getConfigPath(fleetName)

  if (!fs.existsSync(configPath)) {
    return null
  }

  const fileContent = fs.readFileSync(configPath, 'utf8')
  return JSON.parse(fileContent) as CrossChainDeploymentConfig
}

/**
 * Checks if cross-chain deployment is in progress for a fleet
 * @param fleetName Name of the fleet
 * @returns True if cross-chain deployment exists but is incomplete
 */
export function isDeploymentInProgress(fleetName: string): boolean {
  const config = loadCrossChainConfig(fleetName)

  if (!config) {
    return false
  }

  // If we have either address but not both, the deployment is in progress
  return Boolean(
    (config.fleetProxyAddress && !config.crossChainArkAddress) ||
      (!config.fleetProxyAddress && config.crossChainArkAddress),
  )
}
