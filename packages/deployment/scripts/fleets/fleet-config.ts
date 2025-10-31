import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import { FleetConfig } from '../../types/config-types'
import { FleetConfigSchema } from '../lib/infrastructure/zod-schemas'

/**
 * Retrieves the directory path for fleet configuration files.
 * @returns The path to the fleet configuration directory.
 */
export function getFleetConfigDir() {
  return path.resolve(__dirname, '..', '..', 'config', 'fleets')
}

/**
 * Loads a fleet configuration from a file.
 * @param filePath - The path to the fleet configuration file.
 * @returns The fleet configuration object.
 * @throws Will throw an error if the file does not exist or cannot be parsed.
 */
export function loadFleetConfig(filePath: string): FleetConfig {
  const fullPath = path.resolve(filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Fleet definition file not found: ${fullPath}`)
  }

  const fileContent = fs.readFileSync(fullPath, 'utf8')
  const parsed = FleetConfigSchema.safeParse(JSON.parse(fileContent))
  if (!parsed.success) {
    throw new Error(`Invalid Fleet config schema: ${fullPath} -> ${parsed.error.message}`)
  }
  return parsed.data as unknown as FleetConfig
}

/**
 * Prompts the user for the fleet definition file and loads it.
 * @param isBummer - Optional parameter to filter for bummer fleet configs
 * @returns The loaded fleet definition object.
 */
export async function getFleetConfig(isBummer?: boolean): Promise<FleetConfig> {
  const fleetsDir = getFleetConfigDir()
  const fleetFiles = fs
    .readdirSync(fleetsDir)
    .filter((file) => file.endsWith('.json'))
    .filter((file) => (isBummer ? file.includes('.bummer') : !file.includes('.bummer')))

  if (fleetFiles.length === 0) {
    throw new Error(
      `No ${isBummer ? 'bummer ' : ''}fleet config files found in the fleets directory.`,
    )
  }

  const response = await prompts({
    type: 'select',
    name: 'fleetConfigFile',
    message: `Select the ${isBummer ? 'bummer ' : ''}fleet config file:`,
    choices: fleetFiles.map((file) => ({ title: file, value: file })),
  })

  const fleetConfigPath = path.resolve(fleetsDir, response.fleetConfigFile)
  console.log(kleur.green(`Loading fleet config from: ${fleetConfigPath}`))
  const fleetConfig = loadFleetConfig(fleetConfigPath)
  return { ...fleetConfig, details: JSON.stringify(fleetConfig.details) }
}
