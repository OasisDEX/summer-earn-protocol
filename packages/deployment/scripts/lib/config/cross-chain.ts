import fs from 'fs'
import path from 'path'

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
