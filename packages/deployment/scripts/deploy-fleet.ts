import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { createFleetModule, FleetContracts } from '../ignition/modules/fleet'
import { BaseConfig, FleetConfig } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { deployArk } from './common/ark-deployment'
import { GOVERNOR_ROLE } from './common/constants'
import { getFleetConfigDir } from './common/fleet-deployment-files-helpers'
import { grantCommanderRole } from './common/grant-commander-role'
import { saveFleetDeploymentJson } from './common/save-fleet-deployment-json'
import { getConfigByNetwork } from './helpers/config-handler'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from './helpers/constants'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { loadFleetConfig } from './helpers/fleet-definition-handler'
import { getChainId } from './helpers/get-chainid'
import { hashDescription } from './helpers/hash-description'
import { constructLzOptions } from './helpers/layerzero-options'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'
import {
  CrossChainContent,
  generateFleetProposalDescription,
  SingleChainContent,
} from './helpers/proposal-helpers'
import { createTallyProposal, formatTallyProposalUrl } from './helpers/tally-helpers'
import { getAssetAddress } from './helpers/token-helpers'
import { validateToken } from './helpers/validation'

/**
 * Deploys all Arks specified in the fleet definition
 * @param {FleetConfig} fleetDefinition - The fleet definition object
 * @param {BaseConfig} config - The configuration object
 * @returns {Promise<Address[]>} Array of deployed Ark addresses
 */
async function deployArks(fleetDefinition: FleetConfig, config: BaseConfig): Promise<Address[]> {
  const deployedArks: Address[] = []
  const MAX_RETRIES = 5
  const DELAY = 13000 // 13 seconds

  for (const arkConfig of fleetDefinition.arks) {
    console.log(
      kleur.bgWhite().bold(`\n ------------------------------------------------------------`),
    )
    console.log(kleur.cyan().bold(`\nDeploying ${arkConfig.type}...`))

    let retries = 0
    while (retries <= MAX_RETRIES) {
      try {
        const arkAddress = await deployArk(arkConfig, config, fleetDefinition.depositCap)
        deployedArks.push(arkAddress)
        console.log(kleur.green().bold(`Successfully deployed ${arkConfig.type} at ${arkAddress}`))
        break
      } catch (error) {
        if (retries === MAX_RETRIES) {
          console.error(
            kleur.red().bold(`Failed to deploy ${arkConfig.type} after ${MAX_RETRIES} attempts`),
          )
          throw error
        }

        retries++
        console.log(
          kleur.yellow().bold(`Deployment attempt ${retries} failed, retrying in 13 seconds...`),
        )
        await new Promise((resolve) => setTimeout(resolve, DELAY))
      }
    }
  }

  return deployedArks
}

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

  // Determine if this is a hub or satellite chain
  const isHubChain = network === HUB_CHAIN_NAME
  console.log(kleur.blue('Chain Type:'), isHubChain ? kleur.cyan('Hub') : kleur.cyan('Satellite'))

  console.log(kleur.green().bold('Starting Fleet deployment process...'))

  const config = getConfigByNetwork(
    network,
    { common: true, gov: true, core: true },
    useBummerConfig,
  )

  const fleetDefinition = await getFleetConfig()
  validateToken(config, fleetDefinition.assetSymbol)

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
      for (const arkAddress of deployedArkAddresses) {
        await grantCommanderRole(
          config.deployedContracts.gov.protocolAccessManager.address as Address,
          arkAddress,
          deployedFleet.fleetCommander.address,
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
        )
      } else {
        await createSatelliteGovernanceProposal(
          deployedFleet,
          bufferArkAddress,
          deployedArkAddresses,
          config,
          fleetDefinition,
          useBummerConfig,
        )
      }
    }

    logDeploymentResults(deployedFleet)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for the fleet definition file and loads it.
 * @returns The loaded fleet definition object.
 */
async function getFleetConfig(): Promise<FleetConfig> {
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
  fleetDefinition: FleetConfig,
  config: BaseConfig,
  asset: string,
) {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  const name = fleetDefinition.fleetName.replace(/\W/g, '')
  const fleetModule = createFleetModule(`FleetModule_${name}`)

  const deployedModule = await hre.ignition.deploy(fleetModule, {
    parameters: {
      [`FleetModule_${name}`]: {
        configurationManager: config.deployedContracts.core.configurationManager.address,
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        fleetName: fleetDefinition.fleetName,
        fleetSymbol: fleetDefinition.symbol,
        fleetDetails: fleetDefinition.details,
        asset,
        initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
        initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
        depositCap: fleetDefinition.depositCap,
        initialTipRate: fleetDefinition.initialTipRate,
        fleetCommanderRewardsManagerFactory:
          config.deployedContracts.core.fleetCommanderRewardsManagerFactory.address,
      },
    },
    deploymentId,
  })
  await addFleetToHarbor(
    deployedModule.fleetCommander.address,
    config.deployedContracts.core.harborCommand.address as Address,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  return deployedModule
}

/**
 * Logs the results of the deployment, including important addresses and next steps.
 * @param {FleetContracts} deployedFleet - The deployed fleet contracts.
 */
function logDeploymentResults(deployedFleet: FleetContracts) {
  ModuleLogger.logFleet(deployedFleet)

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
  console.log('Deployer: ', deployer.account.address)
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])
  if (hasGovernorRole) {
    const harborCommand = await hre.viem.getContractAt(
      'HarborCommand' as string,
      harborCommandAddress,
    )
    const isEnlisted = await harborCommand.read.activeFleetCommanders([fleetCommanderAddress])
    if (!isEnlisted) {
      const hash = await harborCommand.write.enlistFleetCommander([fleetCommanderAddress])
      await publicClient.waitForTransactionReceipt({
        hash: hash,
      })
      console.log(kleur.green('Fleet added to Harbor Command successfully!'))
    } else {
      console.log(kleur.yellow('Fleet already enlisted in Harbor Command'))
    }
  } else {
    console.log(kleur.red('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
    console.log(
      kleur.red(
        `Please add the fleet @ ${fleetCommanderAddress} to the Harbor Command (${harborCommandAddress}) via governance`,
      ),
    )
  }
}

/**
 * Creates a governance proposal on the hub chain and optionally submits a draft to Tally
 */
async function createHubGovernanceProposal(
  deployedFleet: FleetContracts,
  bufferArkAddress: Address,
  deployedArkAddresses: Address[],
  config: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
) {
  // Use the correct governor address from the config
  const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
  const harborCommandAddress = config.deployedContracts.core.harborCommand.address as Address
  const protocolAccessManagerAddress = config.deployedContracts.gov.protocolAccessManager
    .address as Address

  // Prepare the proposal targets, values, and calldatas
  const targets: Address[] = []
  const values: bigint[] = []
  const calldatas: Hex[] = []

  // 1. Add Fleet to Harbor Command
  targets.push(harborCommandAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function enlistFleetCommander(address fleetCommander) external']),
      args: [deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
  targets.push(protocolAccessManagerAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function grantCommanderRole(address arkAddress, address account) external']),
      args: [bufferArkAddress, deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 2.1 Grant COMMANDER_ROLE to Fleet Commander for each Ark
  for (const arkAddress of deployedArkAddresses) {
    targets.push(protocolAccessManagerAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCommanderRole(address arkAddress, address account) external',
        ]),
        args: [arkAddress, deployedFleet.fleetCommander.address],
      }) as Hex,
    )
  }

  // 3. Add each Ark to the Fleet Commander
  for (const arkAddress of deployedArkAddresses) {
    targets.push(deployedFleet.fleetCommander.address)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi(['function addArk(address ark) external']),
        args: [arkAddress],
      }) as Hex,
    )
  }

  // Replace the try/catch block for proposal submission with Tally API usage
  try {
    console.log(kleur.cyan('Creating Tally draft proposal with the following actions:'))
    console.log(kleur.yellow('- Add Fleet to Harbor Command'))
    console.log(kleur.yellow('- Grant COMMANDER_ROLE to Fleet Commander for BufferArk'))
    console.log(kleur.yellow(`- Add ${deployedArkAddresses.length} Arks to the Fleet`))

    const proposalContent = generateFleetProposalDescription(
      deployedFleet,
      fleetDefinition,
      deployedArkAddresses,
      bufferArkAddress,
      false, // isCrossChain
      hre.network.name, // targetChain
      HUB_CHAIN_NAME + (useBummerConfig ? ' (Bummer)' : ' (Production)'), // hubChain
    ) as SingleChainContent

    // Generate proposal details - use the correct chain ID based on whether we're using bummer config
    const chainId = HUB_CHAIN_ID
    const governorId = `eip155:${chainId}:${governorAddress}`
    const title = proposalContent.sourceTitle

    // Create executable calls array for Tally
    const executableCalls = targets.map((target, index) => ({
      target,
      calldata: calldatas[index],
      signature: '',
      value: values[index].toString(),
      type: 'custom',
    }))

    // Submit to Tally API
    const response = await createTallyProposal(
      governorId,
      title,
      proposalContent.sourceDescription,
      executableCalls,
    )

    // Get proposal ID and display URL
    const proposalId = response.data.createProposal.id
    console.log(kleur.green(`Tally proposal created successfully! ID: ${proposalId}`))
    const proposalUrl = formatTallyProposalUrl(governorId, proposalId)
    console.log(kleur.blue(`View your proposal at: ${proposalUrl}`))

    console.log(kleur.yellow('The fleet will be activated once this proposal is executed.'))
  } catch (error: any) {
    console.error(kleur.red('Error creating Tally draft proposal:'), error)
    if (error.response) {
      console.error(kleur.red('Error response:'), error.response.data)
    }
  }
}

/**
 * Creates a cross-chain governance proposal from the hub chain to a satellite chain
 */
async function createSatelliteGovernanceProposal(
  deployedFleet: FleetContracts,
  bufferArkAddress: Address,
  deployedArkAddresses: Address[],
  config: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
) {
  console.log(kleur.yellow('Creating cross-chain governance proposal...'))

  // Load the hub chain config with the same bummer setting
  const hubConfig = getConfigByNetwork(
    HUB_CHAIN_NAME,
    { common: true, gov: true, core: true },
    useBummerConfig,
  )

  // 2. Set up clients for the hub chain
  console.log(kleur.blue('Connecting to hub chain:'), kleur.cyan(HUB_CHAIN_NAME))
  console.log(
    kleur.blue('Using config:'),
    useBummerConfig ? kleur.cyan('Bummer/Test') : kleur.cyan('Production'),
  )

  // Get current chain's endpoint ID
  const currentChainEndpointId = config.common.layerZero.eID

  // 3. Prepare the destination (satellite) proposal
  const dstTargets: Address[] = []
  const dstValues: bigint[] = []
  const dstCalldatas: Hex[] = []

  // 3.1 Add Fleet to Harbor Command
  const harborCommandAddress = config.deployedContracts.core.harborCommand.address as Address
  dstTargets.push(harborCommandAddress)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function enlistFleetCommander(address fleetCommander) external']),
      args: [deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 3.2 Grant COMMANDER_ROLE to Fleet Commander for BufferArk
  const protocolAccessManagerAddress = config.deployedContracts.gov.protocolAccessManager
    .address as Address

  dstTargets.push(protocolAccessManagerAddress)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function grantCommanderRole(address arkAddress, address account) external']),
      args: [bufferArkAddress, deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 3.3 Add each Ark to the Fleet Commander
  for (const arkAddress of deployedArkAddresses) {
    dstTargets.push(deployedFleet.fleetCommander.address)
    dstValues.push(0n)
    dstCalldatas.push(
      encodeFunctionData({
        abi: parseAbi(['function addArk(address ark) external']),
        args: [arkAddress],
      }) as Hex,
    )
  }

  // 3.4 Grant COMMANDER_ROLE to Fleet Commander for each Ark
  for (const arkAddress of deployedArkAddresses) {
    dstTargets.push(protocolAccessManagerAddress)
    dstValues.push(0n)
    dstCalldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCommanderRole(address arkAddress, address account) external',
        ]),
        args: [arkAddress, deployedFleet.fleetCommander.address],
      }) as Hex,
    )
  }

  const proposalDescriptions = generateFleetProposalDescription(
    deployedFleet,
    fleetDefinition,
    deployedArkAddresses,
    bufferArkAddress,
    true, // isCrossChain
    hre.network.name, // targetChain
    HUB_CHAIN_NAME + (useBummerConfig ? ' (Bummer)' : ' (Production)'), // hubChain
  ) as CrossChainContent

  const dstDescription = proposalDescriptions.destinationDescription
  const srcDescription = proposalDescriptions.sourceDescription
  const title = proposalDescriptions.sourceTitle

  // 4. Prepare the source (hub) proposal
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  console.log(kleur.blue('Using hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

  const srcTargets = [HUB_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const ESTIMATED_GAS = 400000n
  const lzOptions = constructLzOptions(ESTIMATED_GAS)

  const srcCalldatas = [
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(currentChainEndpointId),
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }) as Hex,
  ]

  // 5. Create Tally draft proposal
  try {
    console.log(kleur.cyan('Creating cross-chain governance proposal with the following actions:'))
    console.log(kleur.yellow('- Add Fleet to Harbor Command'))
    console.log(kleur.yellow('- Grant COMMANDER_ROLE to Fleet Commander for BufferArk'))
    console.log(kleur.yellow(`- Add ${deployedArkAddresses.length} Arks to the Fleet`))

    console.log(kleur.blue('Hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

    // Generate proposal details - use the correct chain ID based on whether we're using bummer config
    const governorId = `eip155:${HUB_CHAIN_ID}:${HUB_GOVERNOR_ADDRESS}`

    // Create executable calls array for Tally
    const executableCalls = srcTargets.map((target, index) => ({
      target,
      calldata: srcCalldatas[index],
      signature: '',
      value: srcValues[index].toString(),
      type: 'custom',
    }))

    // Submit to Tally API
    try {
      const response = await createTallyProposal(governorId, title, srcDescription, executableCalls)

      // Get proposal ID and display URL
      const proposalId = response.data.createProposal.id
      console.log(kleur.green(`Tally proposal created successfully! ID: ${proposalId}`))
      const proposalUrl = formatTallyProposalUrl(governorId, proposalId)
      console.log(kleur.blue(`View your proposal at: ${proposalUrl}`))
      console.log(kleur.yellow('The fleet will be activated once this proposal is executed.'))
    } catch (error: any) {
      console.error(kleur.red('Error creating Tally draft proposal:'), error)
      if (error.response) {
        console.error(kleur.red('Error response:'), error.response.data)
      }

      // Fall back to showing manual submission details
      console.log(kleur.yellow('\nProposal details for manual submission:'))
      console.log(kleur.blue('Governor Address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))
      console.log(kleur.blue('Targets:'), kleur.cyan(JSON.stringify(srcTargets)))
      console.log(kleur.blue('Values:'), kleur.cyan(srcValues.toString()))
      console.log(kleur.blue('Calldatas:'))
      srcCalldatas.forEach((data) => {
        console.log(kleur.cyan(data))
      })
      console.log(kleur.blue('Description:'), kleur.cyan(srcDescription))
      console.log(kleur.yellow('The cross-chain proposal needs to be submitted on the hub chain.'))
    }
  } catch (error: any) {
    console.error(kleur.red('Error preparing cross-chain proposal:'), error)
  }
}

// Execute the deployFleet function and handle any errors
deployFleet().catch((error) => {
  console.error(kleur.red('Error during fleet deployment:'))
  console.error(error)
  process.exit(1)
})
