import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { FleetConfig } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { GOVERNOR_ROLE, HUB_CHAIN_NAME } from './common/constants'
import { getFleetConfig } from './common/fleet-deployment-files-helpers'
import { grantCommanderRole } from './common/grant-commander-role'
import { saveFleetDeploymentJson } from './common/save-fleet-deployment-json'
import { warnIfTenderlyVirtualTestnet } from './common/tenderly-helpers'
import { deployFleetContracts, logDeploymentResults } from './fleets/fleet-contracts'
import { addFleetToHarbor, deployArks, grantCuratorRole } from './fleets/fleet-deployment-helpers'
import {
  createHubGovernanceProposal,
  createSatelliteGovernanceProposal,
} from './fleets/governance-helpers'
import { getConfigByNetwork } from './helpers/config-handler'
import { continueDeploymentCheck } from './helpers/prompt-helpers'
import { getAssetAddress } from './helpers/token-helpers'
import { validateToken } from './helpers/validation'

/**
 * Main function to deploy a fleet.
 * This function orchestrates the entire deployment process, including:
 * - Loading the fleet definition
 * - Getting core contract addresses
 * - Collecting BufferArk parameters
 * - Deploying the fleet and BufferArk contracts
import { FleetConfig } from '../types/config-types'
 * - Logging deployment results
 */
async function deployFleet() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Check if using Tenderly virtual testnet
  const isTenderly = warnIfTenderlyVirtualTestnet(
    'Deployments on Tenderly virtual testnets are temporary and will be lost when the session ends. Consider using a persistent testnet for actual deployments.',
  )

  if (isTenderly) {
    // Maybe ask for confirmation before proceeding
    const response = await prompts({
      type: 'confirm',
      name: 'continue',
      message: 'Do you want to continue with deployment on this Tenderly virtual testnet?',
      initial: false,
    })

    if (!response.continue) {
      console.log(kleur.red('Deployment cancelled.'))
      return
    }
  }

  // Ask about using bummer config at the beginning
  const configResponse = await prompts({
    type: 'select',
    name: 'configType',
    message: 'Select the configuration to use:',
    choices: [
      { title: 'Production Config', value: false },
      { title: 'Bummer/Test Config', value: true },
    ],
  })

  const useBummerConfig = configResponse.configType

  if (useBummerConfig && !isTenderly) {
    console.log(kleur.red('Bummer config is only available on Tenderly virtual testnets.'))
    return
  }

  const configForGovernance = getConfigByNetwork(network, { gov: true }, useBummerConfig)
  const configForCore = getConfigByNetwork(network, { core: true })

  // Combine the two configs
  const config = {
    ...configForGovernance,
    ...configForCore,
  }

  // Determine if this is a hub or satellite chain
  const isHubChain = network === HUB_CHAIN_NAME
  console.log(kleur.blue('Chain Type:'), isHubChain ? kleur.cyan('Hub') : kleur.cyan('Satellite'))

  console.log(kleur.green().bold('Starting Fleet deployment process...'))

  const fleetDefinition = await getFleetConfig()
  validateToken(config, fleetDefinition.assetSymbol)

  // Collect curator address
  const curatorResponse = await prompts({
    type: 'confirm',
    name: 'configureCurator',
    message: 'Do you want to configure a curator for this fleet?',
    initial: false,
  })

  let curatorAddress: Address | undefined
  if (curatorResponse.configureCurator) {
    const curatorAddressResponse = await prompts({
      type: 'text',
      name: 'address',
      message: 'Enter the curator address:',
      validate: (value) => (/^0x[a-fA-F0-9]{40}$/.test(value) ? true : 'Invalid Ethereum address'),
    })
    curatorAddress = curatorAddressResponse.address as Address
  }

  console.log(kleur.blue('Fleet Definition:'))
  console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)))

  const assetAddress = getAssetAddress(fleetDefinition.assetSymbol, config)

  if (await confirmDeployment(fleetDefinition)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    // Deploy Fleet first
    const deployedFleet = await deployFleetContracts(fleetDefinition, config, assetAddress)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    const bufferArkAddress = await deployedFleet.fleetCommander.read.bufferArk()

    saveFleetDeploymentJson(fleetDefinition, deployedFleet, bufferArkAddress)

    // Deploy all Arks later
    const deployedArkAddresses = await deployArks(fleetDefinition, config)

    // Check if deployer has governor role
    const protocolAccessManager = await hre.viem.getContractAt(
      'ProtocolAccessManager' as string,
      config.deployedContracts.gov.protocolAccessManager.address as Address,
    )
    const [deployer] = await hre.viem.getWalletClients()
    const hasGovernorRole = await protocolAccessManager.read.hasRole([
      GOVERNOR_ROLE,
      deployer.account.address,
    ])

    if (hasGovernorRole) {
      // Directly execute actions if we have governor role
      console.log(kleur.green('Deployer has governor role. Executing actions directly...'))

      // Add each Ark to the Fleet
      for (const arkAddress of deployedArkAddresses) {
        await addArkToFleet(arkAddress, config, hre, fleetDefinition)
      }

      await addFleetToHarbor(
        deployedFleet.fleetCommander.address,
        config.deployedContracts.core.harborCommand.address as Address,
        config.deployedContracts.gov.protocolAccessManager.address as Address,
      )

      await grantCommanderRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        bufferArkAddress,
        deployedFleet.fleetCommander.address,
        hre,
      )

      // Grant curator role if a curator address was provided
      if (curatorAddress) {
        await grantCuratorRole(
          config.deployedContracts.gov.protocolAccessManager.address as Address,
          deployedFleet.fleetCommander.address,
          curatorAddress,
          hre,
        )
      }
    } else {
      // Create governance proposal
      console.log(
        kleur.yellow('Deployer does not have governor role. Creating governance proposal...'),
      )

      if (isHubChain) {
        await createHubGovernanceProposal(
          deployedFleet,
          bufferArkAddress,
          deployedArkAddresses,
          config,
          fleetDefinition,
          useBummerConfig,
          curatorAddress,
        )
      } else {
        await createSatelliteGovernanceProposal(
          deployedFleet,
          bufferArkAddress,
          deployedArkAddresses,
          config,
          fleetDefinition,
          useBummerConfig,
          isTenderly,
          curatorAddress,
        )
      }
    }

    logDeploymentResults(deployedFleet)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {FleetConfig} fleetDefinition - The fleet definition object.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(fleetDefinition: FleetConfig): Promise<boolean> {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow('Fleet Definition:'))
  console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)))

  return await continueDeploymentCheck()
}

// Execute the deployFleet function and handle any errors
deployFleet().catch((error) => {
  console.error(kleur.red('Error during fleet deployment:'))
  console.error(error)
  process.exit(1)
})
