import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address } from 'viem'
import { ArkType, BaseConfig, FleetConfig } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { GOVERNOR_ROLE, HUB_CHAIN_NAME } from './common/constants'
import {
  getFleetConfig,
  getFleetDeploymentDir,
  getFleetDeploymentFileName,
  loadFleetDeployment,
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
} from './fleets/fleet-governance-helpers'
import { getConfigByNetwork } from './helpers/config-handler'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'
import { getAssetAddress } from './helpers/token-helpers'
import { validateAddress, validateToken } from './helpers/validation'

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

  const config = getConfigByNetwork(
    network,
    { gov: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  // Determine if this is a hub or satellite chain
  const isHubChain = network === HUB_CHAIN_NAME
  console.log(kleur.blue('Chain Type:'), isHubChain ? kleur.cyan('Hub') : kleur.cyan('Satellite'))

  console.log(kleur.green().bold(`Starting ${deploymentMode} process...`))

  // Load fleet configuration
  const fleetDefinition = await getFleetConfig(useBummerConfig)
  validateToken(config, fleetDefinition.assetSymbol)

  // Validate and collect CrossChainArk parameters if needed
  for (const ark of fleetDefinition.arks) {
    if (ark.type === ArkType.CrossChainArk) {
      if (!ark.params.targetChainId || !ark.params.protocol) {
        console.log(kleur.yellow('Missing required parameters for CrossChainArk deployment'))

        // Collect target chain ID
        if (!ark.params.targetChainId) {
          const { targetChainId } = await prompts({
            type: 'text',
            name: 'targetChainId',
            message: 'Enter the target chain ID for CrossChainArk:',
            validate: (value) => (!isNaN(Number(value)) ? true : 'Must be a valid number'),
          })
          ark.params.targetChainId = targetChainId
        }

        // Collect protocol
        if (!ark.params.protocol) {
          const { protocol } = await prompts({
            type: 'text',
            name: 'protocol',
            message: 'Enter the protocol name for CrossChainArk:',
            validate: (value) => (value.length > 0 ? true : 'Protocol name is required'),
          })
          ark.params.protocol = protocol
        }

        console.log(kleur.green('CrossChainArk parameters collected:'))
        console.log(kleur.blue('Target Chain ID:'), kleur.cyan(ark.params.targetChainId))
        console.log(kleur.blue('Protocol:'), kleur.cyan(ark.params.protocol))
      }
    }
  }

  // Handle the deployment based on the chosen mode
  switch (deploymentMode) {
    case DeploymentMode.NEW_FLEET:
      await handleNewFleetDeployment(
        fleetDefinition,
        config,
        isHubChain,
        useBummerConfig,
        isTenderly,
        network,
      )
      break
    case DeploymentMode.ADD_ARK:
      await handleArkAddition(
        fleetDefinition,
        config,
        isHubChain,
        useBummerConfig,
        isTenderly,
        network,
      )
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
  network: string,
) {
  // Get curator from fleet definition
  let curatorAddress = validateAddress(fleetDefinition.curator, 'Curator')

  console.log(kleur.blue('Curator Address:'), kleur.cyan(curatorAddress))

  console.log(kleur.blue('Fleet Definition:'))
  console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)))

  const assetAddress = getAssetAddress(fleetDefinition.assetSymbol, config)

  if (await confirmDeployment(fleetDefinition)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    // Deploy Fleet first
    const deployedFleet = await deployFleetContracts(fleetDefinition, config, assetAddress)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    const bufferArkAddress = await deployedFleet.fleetCommander.read.bufferArk()

    const deployedArks = await deployArks(fleetDefinition, config)
    console.log(kleur.green(`Successfully deployed ${deployedArks.length} arks.`))

    // Save deployment info
    saveFleetDeploymentJson(
      fleetDefinition,
      deployedFleet,
      bufferArkAddress,
      deployedArks,
      useBummerConfig,
    )

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
      for (const arkAddress of deployedArks) {
        await addArkToFleet(arkAddress, config, hre, fleetDefinition)
      }

      await addFleetToHarbor(
        deployedFleet.fleetCommander.address as Address,
        config.deployedContracts.core.harborCommand.address as Address,
        config.deployedContracts.gov.protocolAccessManager.address as Address,
      )

      await grantCommanderRole(
        config.deployedContracts.gov.protocolAccessManager.address as Address,
        bufferArkAddress as Address,
        deployedFleet.fleetCommander.address as Address,
        hre,
      )

      // Grant curator role if a curator address was provided
      if (curatorAddress) {
        await grantCuratorRole(
          config.deployedContracts.gov.protocolAccessManager.address as Address,
          deployedFleet.fleetCommander.address as Address,
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
          console.log('About to get rewards manager address')
          const rewardsManagerAddress = await getRewardsManagerAddress(
            deployedFleet.fleetCommander.address as Address,
          )

          console.log('rewardsManagerAddress', rewardsManagerAddress)

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
          deployedArks,
          config,
          fleetDefinition,
          useBummerConfig,
          curatorAddress,
          network,
        )
      } else {
        await createSatelliteGovernanceProposal(
          deployedFleet,
          bufferArkAddress,
          deployedArks,
          config,
          fleetDefinition,
          useBummerConfig,
          isTenderly,
          curatorAddress,
          network,
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
  network: string,
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

    // Get on-chain arks
    const onChainArks = (await fleetCommander.read.getActiveArks()) as Address[]
    console.log(kleur.blue('On-chain Active Arks:'), kleur.cyan(onChainArks.length.toString()))

    // Get existing arks from deployment file
    const existingArks = deploymentData.arks || []
    console.log(kleur.blue('Deployment File Arks:'), kleur.cyan(existingArks.length.toString()))

    // Compare on-chain state with deployment file
    if (onChainArks.length !== existingArks.length) {
      console.log(
        kleur.red().bold('ERROR: Mismatch detected between on-chain and deployment file!'),
      )
      console.log(kleur.red(`On-chain arks: ${onChainArks.length}`))
      console.log(kleur.red(`Deployment file arks: ${existingArks.length}`))

      onChainArks.forEach((ark) => {
        if (!existingArks.includes(ark)) {
          console.log(kleur.red(`    Ark ${ark} is not in the deployment file.`))
        }
      })

      existingArks.forEach((ark) => {
        if (!onChainArks.includes(ark)) {
          console.log(kleur.red(`    Ark ${ark} is not on the on-chain.`))
        }
      })

      console.log(kleur.yellow('\nOn-chain arks:'))
      onChainArks.forEach((ark, i) => console.log(kleur.cyan(`  ${i + 1}. ${ark}`)))
      console.log(kleur.yellow('\nDeployment file arks:'))
      existingArks.forEach((ark, i) => console.log(kleur.cyan(`  ${i + 1}. ${ark}`)))

      throw new Error(
        'Deployment file state does not match on-chain state. Please reconcile the deployment file before adding new arks.',
      )
    }

    console.log(
      kleur.green('✓ On-chain state matches deployment file. Safe to proceed with ark addition.'),
    )

    // First, ask if we're adding an already deployed ark
    const { isAlreadyDeployed } = await prompts({
      type: 'confirm',
      name: 'isAlreadyDeployed',
      message: 'Are you adding an already deployed Ark?',
      initial: false,
    })

    let deployedArks: Address[] = []

    if (isAlreadyDeployed) {
      // Prompt for the ark address
      const { arkAddress } = await prompts({
        type: 'text',
        name: 'arkAddress',
        message: 'Enter the address of the deployed Ark:',
        validate: (value) => (value.startsWith('0x') ? true : 'Invalid address format'),
      })
      deployedArks = [arkAddress as Address]
    } else {
      // Original flow for checking config and deploying new arks
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

      // Create a new fleet definition that only includes the arks we haven't deployed yet
      const remainingArksToAdd = existingArks.length
        ? fleetDefinition.arks.slice(existingArks.length)
        : fleetDefinition.arks

      if (remainingArksToAdd.length === 0) {
        console.log(
          kleur.yellow('No new arks to deploy. All arks from config are already deployed.'),
        )
        return
      }

      console.log(
        kleur.blue('New arks to deploy:'),
        kleur.cyan(remainingArksToAdd.length.toString()),
      )
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
      deployedArks = await deployArks(newArkFleetDefinition, config)

      if (deployedArks.length === 0) {
        console.log(kleur.yellow('No new arks were deployed.'))
        return
      }

      console.log(kleur.green(`Successfully deployed ${deployedArks.length} new arks.`))
    }

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
      for (const arkAddress of deployedArks) {
        await addArkToFleet(arkAddress, config, hre, fleetDefinition)
      }

      console.log(kleur.green().bold('All Arks added to fleet successfully!'))
    } else {
      // Create governance proposal
      console.log(
        kleur.yellow('Deployer does not have governor role. Creating governance proposal...'),
      )

      // Ask for the specific Discourse URL for this ark addition
      const discourseResponse = await prompts({
        type: 'text',
        name: 'url',
        message: `Enter the Discourse URL for this specific Ark addition proposal (e.g., SIP2.X):`,
        validate: (value) => (value.startsWith('http') ? true : 'Invalid URL format'),
      })

      if (!discourseResponse.url) {
        console.log(kleur.red('Discourse URL is required. Proposal creation cancelled.'))
        return
      }

      // Create a modified fleet definition for the proposal containing the specific URL
      const proposalFleetDefinition = {
        ...fleetDefinition,
        discourseURL: discourseResponse.url,
      }

      if (isHubChain) {
        // Create proposal for just adding arks on the hub chain
        await createArkAdditionProposal(
          fleetCommanderAddress,
          deployedArks,
          config,
          proposalFleetDefinition,
          useBummerConfig,
          network,
        )
      } else {
        // Create cross-chain proposal for adding arks on a satellite chain
        await createArkAdditionCrossChainProposal(
          fleetCommanderAddress,
          deployedArks,
          config,
          proposalFleetDefinition,
          useBummerConfig,
          network,
        )
      }
    }

    // Update the deployment file with the new arks
    const deploymentsDir = getFleetDeploymentDir()
    const fleetFileName = getFleetDeploymentFileName(fleetDefinition)
    const fleetFilePath = path.join(deploymentsDir, fleetFileName)

    // Check if the file exists before reading
    if (fs.existsSync(fleetFilePath)) {
      const currentDeploymentData = loadFleetDeployment(fleetFilePath)

      // Ensure arks array exists
      if (!currentDeploymentData.arks) {
        currentDeploymentData.arks = []
      }

      // Filter out any arks that are already in the array
      const newArks = deployedArks.filter((ark) => !currentDeploymentData.arks.includes(ark))

      if (newArks.length > 0) {
        currentDeploymentData.arks.push(...newArks)
        fs.writeFileSync(fleetFilePath, JSON.stringify(currentDeploymentData, null, 2))

        console.log(kleur.green().bold('Updated fleet deployment configuration saved.'))
        console.log(
          kleur.green(
            `Added ${newArks.length} new arks to a total of ${currentDeploymentData.arks.length} arks.`,
          ),
        )
      } else {
        console.log(kleur.yellow('No new arks to add to the deployment file.'))
      }
    } else {
      console.log(kleur.red(`Error: Fleet deployment file not found at ${fleetFilePath}`))
    }
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
