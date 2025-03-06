import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { FleetConfig } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { GOVERNOR_ROLE, HUB_CHAIN_NAME } from './common/constants'
import {
  getFleetConfig,
  loadFleetDeploymentJson,
  saveFleetDeploymentJson,
} from './common/fleet-deployment-files-helpers'
import { grantCommanderRole } from './common/grant-commander-role'
import { deployFleetContracts, logDeploymentResults } from './fleets/fleet-contracts'
import {
  addFleetToHarbor,
  deployArks,
  getRewardsManagerAddress,
  grantCuratorRole,
  setupFleetRewards,
} from './fleets/fleet-deployment-helpers'
import {
  createArkAdditionCrossChainProposal,
  createArkAdditionProposal,
  createHubGovernanceProposal,
  createSatelliteGovernanceProposal,
} from './fleets/governance-helpers'
import { getConfigByNetwork } from './helpers/config-handler'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'
import { getAssetAddress } from './helpers/token-helpers'
import { validateToken } from './helpers/validation'

/**
 * Deployment modes for the script
 */
enum DeploymentMode {
  NEW_FLEET = 'new_fleet',
  ADD_ARK = 'add_ark',
}

/**
 * Main function to deploy a fleet or add arks to an existing fleet.
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

  // Ask the user what type of deployment they want to perform
  const modeChoices = [
    { title: 'Deploy New Fleet', value: DeploymentMode.NEW_FLEET },
    { title: 'Continue interrupted new fleet deployment', value: DeploymentMode.NEW_FLEET },
    { title: 'Add Ark to Existing Fleet', value: DeploymentMode.ADD_ARK },
  ]

  const modeResponse = await prompts({
    type: 'select',
    name: 'mode',
    message: 'What would you like to do?',
    choices: modeChoices,
  })

  const deploymentMode = modeResponse.mode as DeploymentMode

  // Ask about using bummer config at the beginning
  const useBummerConfig = await promptForConfigType()

  const config = getConfigByNetwork(network, { gov: true, core: true }, useBummerConfig)

  // Determine if this is a hub or satellite chain
  const isHubChain = network === HUB_CHAIN_NAME
  console.log(kleur.blue('Chain Type:'), isHubChain ? kleur.cyan('Hub') : kleur.cyan('Satellite'))

  console.log(kleur.green().bold(`Starting ${deploymentMode} process...`))

  // Load fleet configuration
  const fleetDefinition = await getFleetConfig()
  validateToken(config, fleetDefinition.assetSymbol)

  // Handle the deployment based on the chosen mode
  switch (deploymentMode) {
    case DeploymentMode.NEW_FLEET:
      await handleNewFleetDeployment(
        fleetDefinition,
        config,
        isHubChain,
        useBummerConfig,
        isTenderly,
      )
      break
    case DeploymentMode.ADD_ARK:
      await handleArkAddition(fleetDefinition, config, isHubChain, useBummerConfig, isTenderly)
      break
    default:
      console.log(kleur.red('Invalid deployment mode. Exiting.'))
      return
  }
}

/**
 * Handles new fleet deployment
 */
async function handleNewFleetDeployment(
  fleetDefinition: FleetConfig,
  config: any,
  isHubChain: boolean,
  useBummerConfig: boolean,
  isTenderly: boolean,
) {
  // Get curator from fleet definition
  let curatorAddress = fleetDefinition.curator as Address | undefined

  if (curatorAddress) {
    console.log(kleur.blue('Curator Address:'), kleur.cyan(curatorAddress))
  } else {
    console.log(kleur.yellow('No curator address specified in fleet definition'))
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

    const deployedArkAddresses = await deployArks(fleetDefinition, config)

    saveFleetDeploymentJson(fleetDefinition, deployedFleet, bufferArkAddress, deployedArkAddresses)

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

      // Set up rewards if configured
      if (
        fleetDefinition.rewardTokens &&
        fleetDefinition.rewardAmounts &&
        fleetDefinition.rewardsDuration
      ) {
        try {
          const rewardsManagerAddress = await getRewardsManagerAddress(
            deployedFleet.fleetCommander.address,
          )

          await setupFleetRewards(
            rewardsManagerAddress,
            fleetDefinition.rewardTokens.map((token) => token as Address),
            fleetDefinition.rewardAmounts.map((amount) => BigInt(amount)),
            Array(fleetDefinition.rewardTokens.length).fill(fleetDefinition.rewardsDuration),
          )
        } catch (error: unknown) {
          console.error(
            kleur.red(
              `Error setting up fleet rewards: ${error instanceof Error ? error.message : String(error)}`,
            ),
          )
        }
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
 * Handles adding arks to an existing fleet
 */
async function handleArkAddition(
  fleetDefinition: FleetConfig,
  config: any,
  isHubChain: boolean,
  useBummerConfig: boolean,
  isTenderly: boolean,
) {
  console.log(kleur.green().bold('Loading fleet deployment data...'))

  // Load the fleet deployment JSON instead of asking for address
  const deploymentData = await loadFleetDeploymentJson(fleetDefinition)

  if (!deploymentData || !deploymentData.fleetAddress) {
    console.log(kleur.red('Error: Could not find deployment data for this fleet.'))
    console.log(kleur.yellow('Please ensure you have deployed this fleet previously.'))
    return
  }

  const fleetCommanderAddress = deploymentData.fleetAddress as Address

  // Get the fleet commander contract
  const fleetCommander = await hre.viem.getContractAt(
    'FleetCommander' as string,
    fleetCommanderAddress,
  )

  // Display fleet information
  try {
    const fleetName = (await fleetCommander.read.name()) as string
    const fleetSymbol = (await fleetCommander.read.symbol()) as string
    const bufferArkAddress = (await fleetCommander.read.bufferArk()) as Address

    console.log(kleur.yellow('Fleet Information:'))
    console.log(kleur.blue('Name:'), kleur.cyan(fleetName))
    console.log(kleur.blue('Symbol:'), kleur.cyan(fleetSymbol))
    console.log(kleur.blue('Buffer Ark:'), kleur.cyan(bufferArkAddress))
    console.log(kleur.blue('Fleet Commander:'), kleur.cyan(fleetCommanderAddress))

    // Get existing ark addresses from deployment data
    const existingArkAddresses = deploymentData.arkAddresses || []
    console.log(kleur.blue('Existing Arks:'), kleur.cyan(existingArkAddresses.length.toString()))

    // Check if there are new arks in the config that aren't already deployed
    const configArkTypes = fleetDefinition.arks.map((ark) => ark.type)
    console.log(kleur.blue('Total arks in config:'), kleur.cyan(configArkTypes.length.toString()))
    console.log(kleur.blue('Ark types in config:'), kleur.cyan(configArkTypes.join(', ')))

    // Verify this is the correct fleet
    const verifyResponse = await prompts({
      type: 'confirm',
      name: 'correct',
      message: `Is this the correct fleet (${fleetName}) on ${fleetDefinition.network}?`,
      initial: true,
    })

    if (!verifyResponse.correct) {
      console.log(kleur.red('Operation cancelled. Please restart with the correct fleet.'))
      return
    }

    // Deploy only new Arks
    console.log(kleur.green().bold('Deploying new Arks...'))

    // Create a new fleet definition that only includes the arks we haven't deployed yet
    const remainingArksToAdd = existingArkAddresses.length
      ? fleetDefinition.arks.slice(existingArkAddresses.length)
      : fleetDefinition.arks

    if (remainingArksToAdd.length === 0) {
      console.log(kleur.yellow('No new arks to deploy. All arks from config are already deployed.'))
      return
    }

    console.log(kleur.blue('New arks to deploy:'), kleur.cyan(remainingArksToAdd.length.toString()))
    console.log(
      kleur.blue('New ark types:'),
      kleur.cyan(remainingArksToAdd.map((ark) => ark.type).join(', ')),
    )

    // Create a modified fleet definition with only the new arks
    const newArkFleetDefinition = {
      ...fleetDefinition,
      arks: remainingArksToAdd,
    }

    // Deploy only the new arks
    const deployedArkAddresses = await deployArks(newArkFleetDefinition, config)

    if (deployedArkAddresses.length === 0) {
      console.log(kleur.yellow('No new arks were deployed.'))
      return
    }

    console.log(kleur.green(`Successfully deployed ${deployedArkAddresses.length} new arks.`))

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
      console.log(kleur.green('Deployer has governor role. Adding Arks directly...'))

      // Add each Ark to the Fleet
      for (const arkAddress of deployedArkAddresses) {
        await addArkToFleet(arkAddress, config, hre, fleetDefinition)
      }

      console.log(kleur.green().bold('All Arks added to fleet successfully!'))
    } else {
      // Create governance proposal
      console.log(
        kleur.yellow('Deployer does not have governor role. Creating governance proposal...'),
      )

      if (isHubChain) {
        // Create proposal for just adding arks on the hub chain
        await createArkAdditionProposal(
          fleetCommanderAddress,
          deployedArkAddresses, // Only the newly deployed arks
          config,
          fleetDefinition,
          useBummerConfig,
        )
      } else {
        // Create cross-chain proposal for adding arks on a satellite chain
        await createArkAdditionCrossChainProposal(
          fleetCommanderAddress,
          deployedArkAddresses,
          config,
          fleetDefinition,
          useBummerConfig,
          isTenderly,
        )
      }
    }

    // Update deployment JSON with new Ark addresses
    const updatedArkAddresses = [...existingArkAddresses, ...deployedArkAddresses]

    // Save updated deployment data
    saveFleetDeploymentJson(
      fleetDefinition,
      { fleetCommander: deploymentData.fleetCommander },
      deploymentData.bufferArk,
      updatedArkAddresses,
    )

    console.log(kleur.green().bold('Updated fleet deployment configuration saved.'))
    console.log(
      kleur.green(
        `Added ${deployedArkAddresses.length} new arks to a total of ${updatedArkAddresses.length} arks.`,
      ),
    )
  } catch (error: unknown) {
    console.error(
      kleur.red(
        `Error adding arks to fleet: ${error instanceof Error ? error.message : String(error)}`,
      ),
    )
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
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
})
