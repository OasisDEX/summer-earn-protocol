import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address } from 'viem'
import { FleetContracts } from '../../ignition/modules/fleet'
import { FleetConfig, FleetDeployment } from '../../types/config-types'

/**
 * Retrieves available fleets for the current network from the deployments folder.
 * @param  networkName - The name of the current network.
 * @returns An array of fleet objects compatible with the current network.
 */
export function getAvailableFleets(networkName: string): FleetDeployment[] {
  const deploymentsDir = getFleetDeploymentDir()
  const files = fs.readdirSync(deploymentsDir).filter((file) => file.endsWith('_deployment.json'))
  return files
    .map((file) => {
      return loadFleetDeployment(path.join(deploymentsDir, file))
    })
    .filter((fleet) => fleet.network === networkName)
}

/**
 * Loads a fleet deployment from a file.
 * @param filePath - The path to the fleet deployment file.
 * @returns The fleet deployment object.
 * @throws Will throw an error if the file does not exist or cannot be parsed.
 */
export function loadFleetDeployment(filePath: string): FleetDeployment {
  const fullPath = path.resolve(filePath)
  const fileContent = fs.readFileSync(fullPath, 'utf8')
  return JSON.parse(fileContent) as FleetDeployment
}

/**
 * Generates the filename for a fleet deployment based on its name and network.
 * @param fleetDeployment - The fleet deployment or fleet configuration object.
 * @returns The generated filename for the fleet deployment.
 */
export function getFleetDeploymentFileName(fleetDeployment: FleetDeployment | FleetConfig) {
  return `${fleetDeployment.fleetName.replace(/\W/g, '')}_${fleetDeployment.network}_deployment.json`
}

/**
 * Retrieves the directory path for fleet deployment files.
 * @returns The path to the fleet deployment directory.
 */
export function getFleetDeploymentDir() {
  return path.resolve(__dirname, '..', '..', 'deployments', 'fleets')
}

/**
 * Retrieves the directory path for fleet configuration files.
 * @returns The path to the fleet configuration directory.
 */
export function getFleetConfigDir() {
  return path.resolve(__dirname, '..', '..', 'config', 'fleets')
}

/**
 * Constructs the full path to a fleet deployment file.
 * @param fleetDeployment - The fleet deployment or fleet configuration object.
 * @returns The full path to the fleet deployment file.
 */
export function getFleetDeploymentPath(fleetDeployment: FleetDeployment | FleetConfig) {
  return path.join(getFleetDeploymentDir(), getFleetDeploymentFileName(fleetDeployment))
}

/**
 * Prompts the user for the fleet definition file and loads it.
 * @returns The loaded fleet definition object.
 */
export async function getFleetConfig(): Promise<FleetConfig> {
  const fleetsDir = getFleetConfigDir()
  const fleetFiles = fs.readdirSync(fleetsDir).filter((file) => file.endsWith('.json'))

  if (fleetFiles.length === 0) {
    throw new Error('No fleet config files found in the fleets directory.')
  }

  const response = await prompts({
    type: 'select',
    name: 'fleetConfigFile',
    message: 'Select the fleet config file:',
    choices: fleetFiles.map((file) => ({ title: file, value: file })),
  })

  const fleetConfigPath = path.resolve(fleetsDir, response.fleetConfigFile)
  console.log(kleur.green(`Loading fleet config from: ${fleetConfigPath}`))
  const fleetConfig = loadFleetConfig(fleetConfigPath)
  return { ...fleetConfig, details: JSON.stringify(fleetConfig.details) }
}

export function loadFleetConfig(filePath: string): FleetConfig {
  const fullPath = path.resolve(filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Fleet definition file not found: ${fullPath}`)
  }

  const fileContent = fs.readFileSync(fullPath, 'utf8')
  const fleetConfig = JSON.parse(fileContent) as FleetConfig
  if (
    !fleetConfig.fleetName ||
    !fleetConfig.symbol ||
    !fleetConfig.assetSymbol ||
    !fleetConfig.initialMinimumBufferBalance ||
    !fleetConfig.initialRebalanceCooldown ||
    !fleetConfig.depositCap ||
    !fleetConfig.initialTipRate ||
    !fleetConfig.network ||
    fleetConfig.details === undefined
  ) {
    throw new Error(`Fleet config file is missing required fields: ${fullPath}`)
  }
  return fleetConfig
}

/**
 * Loads the fleet deployment JSON file for a given fleet definition
 */
export async function loadFleetDeploymentJson(fleetDefinition: FleetConfig): Promise<any> {
  const fleetName = fleetDefinition.fleetName.replace(/\s+/g, '').replace(/\\/g, '')
  const network = hre.network.name
  const fileName = `${fleetName}_${network}_deployment.json`
  const filePath = path.join(process.cwd(), 'deployments', 'fleets', fileName)
  console.log(kleur.green().bold(`Loading fleet deployment output file: ${filePath}`))

  try {
    if (fs.existsSync(filePath)) {
      const fileContent = fs.readFileSync(filePath, 'utf8')
      return JSON.parse(fileContent)
    }
    return null
  } catch (error) {
    console.error(kleur.red(`Error loading fleet deployment file: ${error}`))
    return null
  }
}

/**
 * Creates and saves a deployment JSON file with fleet information.
 * @param {any} fleetDefinition - The fleet definition object.
 * @param {FleetContracts} deployedFleet - The deployed fleet contracts.
 */
export function saveFleetDeploymentJson(
  fleetDefinition: FleetConfig,
  deployedFleet: FleetContracts,
  bufferArkAddress: Address,
  deployedArkAddresses?: Address[],
) {
  const deploymentInfo = {
    fleetName: fleetDefinition.fleetName,
    fleetSymbol: fleetDefinition.symbol,
    assetSymbol: fleetDefinition.assetSymbol,
    fleetAddress: deployedFleet.fleetCommander.address,
    bufferArkAddress: bufferArkAddress.toString(),
    network: fleetDefinition.network,
    initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
    initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
    depositCap: fleetDefinition.depositCap,
    initialTipRate: fleetDefinition.initialTipRate,
    arkAddresses: deployedArkAddresses?.map((address) => address.toString()),
  }

  const deploymentDir = getFleetDeploymentDir()
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir, { recursive: true })
  }

  const filePath = getFleetDeploymentPath(fleetDefinition)

  if (fs.existsSync(filePath)) {
    console.log(
      kleur.red(`File ${filePath} already exists. Skipping overwriting fleet deployment JSON.`),
    )
  } else {
    fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2))
  }

  console.log(kleur.green().bold(`Deployment information saved to: ${filePath}`))
}
