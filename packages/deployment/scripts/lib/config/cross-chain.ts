import fs from 'fs'
import path from 'path'
import prompts from 'prompts'
import kleur from 'kleur'

export interface CrossChainConfig {
  fleetName: string
  sourceChainId: number
  hubFleetName: string
  destinations: Array<{
    chainId: number
    name: string
    protocols: Array<{
      protocol: string
      fleetProxyAddress: string
      crossChainArkAddress: string
      satelliteFleetAddress: string
      assetAddress: string
      assetSymbol: string
    }>
  }>
}

export type CrossChainConfigPhase = 'satellite' | 'hub' | 'complete'

export interface CrossChainConfigStatus {
  phase: CrossChainConfigPhase
  missingFields: string[]
  isValid: boolean
  errors: string[]
}

export interface CrossChainConfigSelectionOptions {
  targetChainId?: number
  targetProtocol?: string
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

/**
 * Validates a cross-chain config for a specific phase
 */
export function validateCrossChainConfigPhase(
  config: CrossChainConfig,
  phase: CrossChainConfigPhase,
): { isValid: boolean; errors: string[] } {
  const errors: string[] = []

  // Basic validation
  if (!config.fleetName) {
    errors.push('fleetName is required')
  }
  if (!config.destinations || config.destinations.length === 0) {
    errors.push('destinations array is required and must not be empty')
  }

  // Phase-specific validation
  switch (phase) {
    case 'satellite':
      // Satellite phase: FleetProxy addresses should be present
      for (const dest of config.destinations) {
        for (const protocol of dest.protocols) {
          if (!protocol.fleetProxyAddress) {
            errors.push(`fleetProxyAddress is required for destination ${dest.chainId} protocol ${protocol.protocol}`)
          }
          if (!protocol.satelliteFleetAddress) {
            errors.push(`satelliteFleetAddress is required for destination ${dest.chainId} protocol ${protocol.protocol}`)
          }
        }
      }
      break

    case 'hub':
      // Hub phase: CrossChainArk addresses should be present
      if (!config.sourceChainId || config.sourceChainId === 0) {
        errors.push('sourceChainId is required for hub phase')
      }
      if (!config.hubFleetName) {
        errors.push('hubFleetName is required for hub phase')
      }
      for (const dest of config.destinations) {
        for (const protocol of dest.protocols) {
          if (!protocol.crossChainArkAddress) {
            errors.push(`crossChainArkAddress is required for destination ${dest.chainId} protocol ${protocol.protocol}`)
          }
        }
      }
      break

    case 'complete':
      // Complete phase: All fields should be present
      const hubValidation = validateCrossChainConfigPhase(config, 'hub')
      if (!hubValidation.isValid) {
        errors.push(...hubValidation.errors)
      }
      break
  }

  return {
    isValid: errors.length === 0,
    errors,
  }
}

/**
 * Merges updates into an existing cross-chain config
 */
export function mergeCrossChainConfig(
  existing: CrossChainConfig,
  updates: Partial<CrossChainConfig>,
): CrossChainConfig {
  const merged = { ...existing, ...updates }

  // Merge destinations if provided
  if (updates.destinations) {
    merged.destinations = updates.destinations.map((newDest) => {
      const existingDest = existing.destinations.find((d) => d.chainId === newDest.chainId)
      if (!existingDest) {
        return newDest
      }

      // Merge protocols
      const mergedProtocols = newDest.protocols.map((newProtocol) => {
        const existingProtocol = existingDest.protocols.find((p) => p.protocol === newProtocol.protocol)
        if (!existingProtocol) {
          return newProtocol
        }

        return {
          ...existingProtocol,
          ...newProtocol,
        }
      })

      return {
        ...existingDest,
        ...newDest,
        protocols: mergedProtocols,
      }
    })
  }

  return merged
}

/**
 * Checks if a cross-chain config is complete
 */
export function isCrossChainConfigComplete(config: CrossChainConfig): boolean {
  const validation = validateCrossChainConfigPhase(config, 'complete')
  return validation.isValid
}

/**
 * Gets the status of a cross-chain config
 */
export function getCrossChainConfigStatus(fleetName: string): CrossChainConfigStatus {
  const config = loadCrossChainConfig(fleetName)
  if (!config) {
    return {
      phase: 'satellite',
      missingFields: ['config file'],
      isValid: false,
      errors: ['Cross-chain config file not found'],
    }
  }

  const missingFields: string[] = []
  const errors: string[] = []

  // Check satellite phase
  const satelliteValidation = validateCrossChainConfigPhase(config, 'satellite')
  if (!satelliteValidation.isValid) {
    missingFields.push('satellite components')
    errors.push(...satelliteValidation.errors)
  }

  // Check hub phase
  const hubValidation = validateCrossChainConfigPhase(config, 'hub')
  if (!hubValidation.isValid) {
    missingFields.push('hub components')
    errors.push(...hubValidation.errors)
  }

  // Determine phase
  let phase: CrossChainConfigPhase = 'satellite'
  if (satelliteValidation.isValid && hubValidation.isValid) {
    phase = 'complete'
  } else if (satelliteValidation.isValid) {
    phase = 'hub'
  }

  return {
    phase,
    missingFields,
    isValid: errors.length === 0,
    errors,
  }
}

/**
 * Creates a new cross-chain config in satellite phase
 */
export function createSatellitePhaseConfig(
  fleetName: string,
  destination: {
    chainId: number
    name: string
    fleetProxyAddress: string
    satelliteFleetAddress: string
    protocol?: string
    assetAddress?: string
    assetSymbol?: string
  },
): CrossChainConfig {
  return {
    fleetName,
    sourceChainId: 0, // Will be set later
    hubFleetName: '', // Will be set later
    destinations: [
      {
        chainId: destination.chainId,
        name: destination.name,
        protocols: [
          {
            protocol: destination.protocol || 'summerfi',
            fleetProxyAddress: destination.fleetProxyAddress,
            crossChainArkAddress: '', // Will be set later
            satelliteFleetAddress: destination.satelliteFleetAddress,
            assetAddress: destination.assetAddress || '', // Will be set later
            assetSymbol: destination.assetSymbol || '', // Will be set later
          },
        ],
      },
    ],
  }
}

/**
 * Ensures the cross-chain config directory exists and returns available config files
 */
export function ensureCrossChainConfigDirectory(configDir: string): string[] {
  console.log(kleur.blue('Looking for cross-chain config files...'))
  console.log(kleur.blue(`Config directory: ${configDir}`))

  if (!fs.existsSync(configDir)) {
    console.log(kleur.yellow('Cross-chain config directory does not exist'))
    fs.mkdirSync(configDir, { recursive: true })
    console.log(kleur.green('Created cross-chain config directory'))
  }

  const configFiles = fs.readdirSync(configDir).filter((file) => file.endsWith('.json'))

  if (configFiles.length === 0) {
    console.error(kleur.red('No cross-chain config files found.'))
    console.error(kleur.red(`Expected config files in: ${configDir}`))
    console.error(
      kleur.yellow('The cross-chain config should have been created during FleetProxy deployment.'),
    )
    throw new Error('No cross-chain config files found')
  }

  console.log(kleur.blue('Available cross-chain config files:'))
  configFiles.forEach((file) => {
    console.log(kleur.cyan(`  - ${file}`))
  })

  return configFiles
}

/**
 * Selects and loads a cross-chain config file, optionally matching by chain ID and protocol
 */
export async function selectCrossChainConfig(
  configDir: string,
  configFiles: string[],
  options?: CrossChainConfigSelectionOptions,
): Promise<{ selectedConfigFile: string; crossChainConfig: CrossChainConfig } | null> {
  if (options?.targetChainId && options?.targetProtocol) {
    const matchingFile = await findMatchingConfigFile(
      configDir,
      configFiles,
      options.targetChainId,
      options.targetProtocol,
    )
    if (!matchingFile) {
      throw new Error(
        `No config file found for chain ${options.targetChainId} and protocol ${options.targetProtocol}`,
      )
    }
    return {
      selectedConfigFile: matchingFile,
      crossChainConfig: parseCrossChainConfig(configDir, matchingFile),
    }
  }

  const { configFile } = await prompts({
    type: 'select',
    name: 'configFile',
    message: 'Select a cross-chain configuration file:',
    choices: configFiles.map((file) => ({ title: file, value: file })),
  })

  if (!configFile) {
    console.log(kleur.red().bold('No config file selected. Exiting.'))
    return null
  }

  console.log(kleur.blue(`Loading config from: ${path.join(configDir, configFile)}`))
  return {
    selectedConfigFile: configFile,
    crossChainConfig: parseCrossChainConfig(configDir, configFile),
  }
}

/**
 * Parses a cross-chain config file from a directory
 */
export function parseCrossChainConfig(configDir: string, configFile: string): CrossChainConfig {
  const configPath = path.join(configDir, configFile)
  return JSON.parse(fs.readFileSync(configPath, 'utf8')) as CrossChainConfig
}

/**
 * Validates and returns the fleet name from a cross-chain config
 */
export function ensureConfigFleetName(
  crossChainConfig: CrossChainConfig,
  providedFleetName: string,
): string {
  const configFleetName = crossChainConfig.fleetName
  if (!configFleetName || configFleetName.trim() === '') {
    throw new Error(
      'Cross-chain config file is missing fleetName. Please ensure the config file is valid.',
    )
  }

  if (configFleetName !== providedFleetName) {
    console.log(
      kleur.yellow(`Using fleet name from config: ${configFleetName} (input was: ${providedFleetName})`),
    )
  }

  return configFleetName
}

/**
 * Resolves target destination (chain ID and protocol) from config, optionally using provided options
 */
export async function resolveTargetDestination(
  crossChainConfig: CrossChainConfig,
  options?: CrossChainConfigSelectionOptions,
): Promise<{ targetChainId: number; targetProtocol: string } | null> {
  if (options?.targetChainId && options?.targetProtocol) {
    return {
      targetChainId: options.targetChainId,
      targetProtocol: options.targetProtocol,
    }
  }

  const destinations = crossChainConfig.destinations.map((dest) => ({
    title: `${dest.name} (Chain ID: ${dest.chainId})`,
    value: dest.chainId,
  }))

  if (destinations.length === 0) {
    console.error(kleur.red('No destinations defined in the cross-chain config.'))
    throw new Error('No destinations defined')
  }

  const { selectedChainId } = await prompts({
    type: 'select',
    name: 'selectedChainId',
    message: 'Select target chain:',
    choices: destinations,
  })

  if (!selectedChainId) {
    console.log(kleur.red().bold('No chain selected. Exiting.'))
    return null
  }

  const destination = crossChainConfig.destinations.find((d) => d.chainId === selectedChainId)
  if (!destination) {
    console.error(kleur.red('Selected destination not found in config.'))
    throw new Error('Invalid destination')
  }

  const protocols = destination.protocols.map((p) => ({
    title: p.protocol,
    value: p.protocol,
  }))

  const { selectedProtocol } = await prompts({
    type: 'select',
    name: 'selectedProtocol',
    message: 'Select protocol:',
    choices: protocols,
  })

  if (!selectedProtocol) {
    console.log(kleur.red().bold('No protocol selected. Exiting.'))
    return null
  }

  return {
    targetChainId: selectedChainId,
    targetProtocol: selectedProtocol,
  }
}

/**
 * Finds a config file matching the given chain ID and protocol
 */
export async function findMatchingConfigFile(
  configDir: string,
  configFiles: string[],
  targetChainId: number,
  targetProtocol: string,
): Promise<string | null> {
  for (const file of configFiles) {
    const configPath = path.join(configDir, file)
    try {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8')) as CrossChainConfig
      const matchingDest = config.destinations.find((dest) => dest.chainId === targetChainId)
      if (matchingDest) {
        const matchingProtocol = matchingDest.protocols.find((p) => p.protocol === targetProtocol)
        if (matchingProtocol) {
          return file
        }
      }
    } catch (error) {
      console.warn(kleur.yellow(`Error reading config file ${file}: ${error}`))
    }
  }
  return null
}
