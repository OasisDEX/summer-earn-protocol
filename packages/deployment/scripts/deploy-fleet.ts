import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, keccak256, toBytes } from 'viem'
import { CoreContracts } from '../ignition/modules/core'
import { createFleetModule, FleetContracts } from '../ignition/modules/fleet'
import { BaseConfig, FleetDefinition } from '../types/config-types'
import { grantCommanderRole } from './common/grant-commander-role'
import { saveFleetDeploymentJson } from './common/save-fleet-deployment-json'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { loadFleetDefinition } from './helpers/fleet-definition-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'

/**
 * Main function to deploy a fleet.
 * This function orchestrates the entire deployment process, including:
 * - Loading the fleet definition
 * - Getting core contract addresses
 * - Collecting BufferArk parameters
 * - Deploying the fleet and BufferArk contracts
 * - Logging deployment results
 */
async function deployFleet() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))
  const config = getConfigByNetwork(network)

  console.log(kleur.green().bold('Starting Fleet deployment process...'))

  const fleetDefinition = await getFleetDefinition()
  console.log(kleur.blue('Fleet Definition:'))
  console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)))

  const coreContracts = config.deployedContracts.core
  const assetAddress = getAssetAddress(fleetDefinition.assetSymbol, config)

  if (await confirmDeployment(fleetDefinition)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedFleet = await deployFleetContracts(fleetDefinition, coreContracts, assetAddress)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    const bufferArkAddress = await deployedFleet.fleetCommander.read.bufferArk()

    await grantCommanderRole(
      coreContracts.protocolAccessManager.address as Address,
      bufferArkAddress,
      deployedFleet.fleetCommander.address,
      hre,
    )

    logDeploymentResults(deployedFleet)
    saveFleetDeploymentJson(fleetDefinition, deployedFleet, bufferArkAddress)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for the fleet definition file and loads it.
 * @returns The loaded fleet definition object.
 */
async function getFleetDefinition(): Promise<FleetDefinition> {
  const fleetsDir = path.resolve(__dirname, '..', 'config', 'fleets')
  const fleetFiles = fs.readdirSync(fleetsDir).filter((file) => file.endsWith('.json'))

  if (fleetFiles.length === 0) {
    throw new Error('No fleet definition files found in the fleets directory.')
  }

  const response = await prompts({
    type: 'select',
    name: 'fleetDefinitionFile',
    message: 'Select the fleet definition file:',
    choices: fleetFiles.map((file) => ({ title: file, value: file })),
  })

  const fleetDefinitionPath = path.resolve(fleetsDir, response.fleetDefinitionFile)
  console.log(kleur.green(`Loading fleet definition from: ${fleetDefinitionPath}`))
  // todo: remove this once we have a details field in the fleet definition
  return { ...loadFleetDefinition(fleetDefinitionPath), details: JSON.stringify('') }
}

/**
 * Retrieves the asset address from the config based on the asset symbol.
 * @param {string} assetSymbol - The symbol of the asset.
 * @param {BaseConfig} config - The configuration object.
 * @returns {string} The address of the asset.
 * @throws {Error} If the asset symbol is not found in the config.
 */
function getAssetAddress(assetSymbol: string, config: BaseConfig): string {
  const assetSymbolLower = assetSymbol.toLowerCase() as keyof typeof config.tokens
  if (!Object.keys(config.tokens).includes(assetSymbolLower)) {
    throw new Error(`No token address for symbol ${assetSymbol} found in config`)
  }
  return config.tokens[assetSymbolLower]
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {any} fleetDefinition - The fleet definition object.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(fleetDefinition: any): Promise<boolean> {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow('Fleet Definition:'))
  console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)))

  return await continueDeploymentCheck()
}

/**
 * Deploys the Fleet and BufferArk contracts using Hardhat Ignition.
 * @param {any} fleetDefinition - The fleet definition object.
 * @param {CoreContracts} coreContracts - The core contract addresses.
 * @param {string} asset - The address of the asset.
 * @returns {Promise<FleetContracts>} The deployed fleet contracts.
 */
async function deployFleetContracts(
  fleetDefinition: FleetDefinition,
  coreContracts: CoreContracts,
  asset: string,
) {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  const name = fleetDefinition.fleetName.replace(/\W/g, '')
  const fleetModule = createFleetModule(`FleetModule_${name}`)
  const deployedModule = await hre.ignition.deploy(fleetModule, {
    parameters: {
      [`FleetModule_${name}`]: {
        configurationManager: coreContracts.configurationManager.address,
        protocolAccessManager: coreContracts.protocolAccessManager.address,
        fleetName: fleetDefinition.fleetName,
        fleetSymbol: fleetDefinition.symbol,
        fleetDetails: fleetDefinition.details,
        asset,
        initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
        initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
        depositCap: fleetDefinition.depositCap,
        initialTipRate: fleetDefinition.initialTipRate,
        fleetCommanderRewardsManagerFactory:
          coreContracts.fleetCommanderRewardsManagerFactory.address,
      },
    },
    deploymentId,
  })
  await addFleetToHarbor(
    deployedModule.fleetCommander.address,
    coreContracts.harborCommand.address as Address,
    coreContracts.protocolAccessManager.address as Address,
  )
  return deployedModule
}

/**
 * Logs the results of the deployment, including important addresses and next steps.
 * @param {FleetContracts} deployedFleet - The deployed fleet contracts.
 */
function logDeploymentResults(deployedFleet: FleetContracts) {
  ModuleLogger.logFleet(deployedFleet)

  console.log(kleur.yellow().bold('\nIMPORTANT: Commander roles need to be granted via governance'))
  console.log(kleur.yellow('For each initial Ark, the buffer Ark, and the Fleet Commander, call:'))
  console.log(
    kleur.cyan(
      `protocolAccessManager.grantCommanderRole(<address of the ark>, ${deployedFleet.fleetCommander.address})`,
    ),
  )

  console.log(kleur.green('Fleet deployment completed successfully!'))
  console.log(
    kleur.yellow('Fleet Commander Address:'),
    kleur.cyan(deployedFleet.fleetCommander.address),
  )
}
async function addFleetToHarbor(
  fleetCommanderAddress: Address,
  harborCommandAddress: Address,
  protocolAccessManagerAddress: Address,
) {
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    keccak256(toBytes('GOVERNOR_ROLE')),
    deployer.account.address,
  ])
  if (hasGovernorRole) {
    const hash = await (
      await hre.viem.getContractAt('HarborCommand' as string, harborCommandAddress)
    ).write.enlistFleetCommander([fleetCommanderAddress])
    await publicClient.waitForTransactionReceipt({
      hash: hash,
    })
    console.log(kleur.green('Fleet added to Harbor Command successfully!'))
  } else {
    console.log(kleur.yellow('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
    console.log(
      kleur.yellow(
        `Please add the fleet @ ${fleetCommanderAddress} to the Harbor Command (${harborCommandAddress}) via governance`,
      ),
    )
  }
}

// Execute the deployFleet function and handle any errors
deployFleet().catch((error) => {
  console.error(kleur.red('Error during fleet deployment:'))
  console.error(error)
  process.exit(1)
})
