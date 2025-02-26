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
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { loadFleetConfig } from './helpers/fleet-definition-handler'
import { getChainId } from './helpers/get-chainid'
import { submitProposal } from './helpers/governance-helpers'
import { hashDescription } from './helpers/hash-description'
import { constructLzOptions } from './helpers/layerzero-options'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'
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
  const config = getConfigByNetwork(network, { common: true, gov: true, core: true })

  // Determine if this is a hub or satellite chain
  const isHubChain = network === 'base' || network === 'baseSepolia' // Adjust as needed
  console.log(kleur.blue('Chain Type:'), isHubChain ? kleur.cyan('Hub') : kleur.cyan('Satellite'))

  console.log(kleur.green().bold('Starting Fleet deployment process...'))

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
        )
      } else {
        await createSatelliteGovernanceProposal(
          deployedFleet,
          bufferArkAddress,
          deployedArkAddresses,
          config,
          fleetDefinition,
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
) {
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

  const description = `Activate ${fleetDefinition.fleetName} Fleet with ${deployedArkAddresses.length} Arks`

  // Submit the proposal
  try {
    const publicClient = await hre.viem.getPublicClient()
    const [walletClient] = await hre.viem.getWalletClients()

    console.log(kleur.cyan('Creating governance proposal with the following actions:'))
    console.log(kleur.yellow('- Add Fleet to Harbor Command'))
    console.log(kleur.yellow('- Grant COMMANDER_ROLE to Fleet Commander for BufferArk'))
    console.log(kleur.yellow(`- Add ${deployedArkAddresses.length} Arks to the Fleet`))

    const governorAbi = parseAbi([
      'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) public returns (uint256)',
      'function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) public pure returns (uint256)',
    ])

    const hash = await walletClient.writeContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'propose',
      args: [targets, values, calldatas, description],
      gas: 500000n,
      maxFeePerGas: await publicClient.getGasPrice(),
    })

    console.log(kleur.green('Proposal submitted. Transaction hash:'), kleur.cyan(hash))

    // Wait for the transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log(
      kleur.green('Proposal transaction mined. Block number:'),
      kleur.cyan(receipt.blockNumber.toString()),
    )

    // Get the proposal ID
    const proposalId = await publicClient.readContract({
      address: governorAddress,
      abi: governorAbi,
      functionName: 'hashProposal',
      args: [targets, values, calldatas, hashDescription(description)],
    })

    console.log(kleur.green('Proposal ID:'), kleur.cyan(proposalId.toString()))
    console.log(kleur.yellow('The fleet will be activated once this proposal is executed.'))

    try {
      await submitProposal({
        title: `Deploy Fleet: ${fleetDefinition.fleetName}`,
        description: generateProposalDescription(
          deployedFleet,
          fleetDefinition,
          deployedArkAddresses,
          bufferArkAddress,
        ),
        targets,
        values,
        calldatas,
        governorAddress,
      })
    } catch (error) {
      console.error(kleur.red('Failed to create Tally draft proposal:'), error)
    }
  } catch (error: any) {
    console.error(kleur.red('Error submitting proposal:'), error)
    if (error.cause) {
      console.error(kleur.red('Error cause:'), error.cause)
      if (error.cause.data) {
        console.error(kleur.red('Error data:'), error.cause.data)
      }
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
) {
  console.log(kleur.yellow('Creating cross-chain governance proposal...'))

  // For cross-chain proposals, we need to:
  // 1. Prompt for hub chain details
  const hubChainResponse = await prompts({
    type: 'select',
    name: 'hubChain',
    message: 'Select the hub chain:',
    choices: [
      { title: 'Base Mainnet', value: 'base' },
      { title: 'Base Sepolia', value: 'baseSepolia' },
    ],
  })

  const hubChainName = hubChainResponse.hubChain
  const hubConfig = getConfigByNetwork(hubChainName, { common: true, gov: true, core: true })

  // 2. Set up clients for the hub chain
  console.log(kleur.blue('Connecting to hub chain:'), kleur.cyan(hubChainName))

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

  const dstDescription = `Activate ${fleetDefinition.fleetName} Fleet with ${deployedArkAddresses.length} Arks`

  // 4. Prepare the source (hub) proposal
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  const srcTargets = [HUB_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const lzOptions = constructLzOptions(300000n)

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

  const srcDescription = `Cross-chain proposal: ${dstDescription}`

  // 5. Submit the hub proposal
  try {
    console.log(kleur.cyan('Creating cross-chain governance proposal with the following actions:'))
    console.log(kleur.yellow('- Add Fleet to Harbor Command'))
    console.log(kleur.yellow('- Grant COMMANDER_ROLE to Fleet Commander for BufferArk'))
    console.log(kleur.yellow(`- Add ${deployedArkAddresses.length} Arks to the Fleet`))

    console.log(kleur.blue('Hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

    const hubProposalTitle = `Cross-chain Proposal: Deploy ${fleetDefinition.fleetName} Fleet on ${hre.network.name}`

    // Generate full proposal description with more context
    const proposalDescription = `# Cross-chain Fleet Deployment Proposal

## Summary
This is a cross-chain governance proposal to activate the ${fleetDefinition.fleetName} Fleet on ${hre.network.name}.

## Technical Details
- Hub Chain: ${hubChainName}
- Target Chain: ${hre.network.name}
- Fleet Commander: ${deployedFleet.fleetCommander.address}
- Buffer Ark: ${bufferArkAddress}
- Number of Arks: ${deployedArkAddresses.length}

## Actions
This proposal will execute the following actions on ${hre.network.name}:
1. Add Fleet to Harbor Command
2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
3. Add ${deployedArkAddresses.length} Arks to the Fleet

## Cross-chain Mechanism
This proposal uses LayerZero to execute governance actions across chains.`

    console.log(kleur.blue('\nOptions for proceeding:'))
    console.log(kleur.yellow('1. Submit this proposal on the hub chain directly'))
    console.log(kleur.yellow('2. Note the details for manual submission'))

    const submitResponse = await prompts({
      type: 'select',
      name: 'option',
      message: 'How would you like to proceed?',
      choices: [
        { title: 'Submit proposal on hub chain', value: 'submit' },
        { title: 'Just show details for manual submission', value: 'manual' },
      ],
    })

    if (submitResponse.option === 'submit') {
      // Submit the proposal using our helper
      await submitProposal({
        title: hubProposalTitle,
        description: proposalDescription,
        targets: srcTargets,
        values: srcValues,
        calldatas: srcCalldatas,
        governorAddress: HUB_GOVERNOR_ADDRESS,
      })
    } else {
      // Just display the details for manual submission
      console.log(kleur.yellow('\nProposal details for manual submission:'))
      console.log(kleur.blue('Governor Address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))
      console.log(kleur.blue('Targets:'), kleur.cyan(JSON.stringify(srcTargets)))
      console.log(kleur.blue('Values:'), kleur.cyan(srcValues.toString()))
      console.log(kleur.blue('Calldatas:'))
      srcCalldatas.forEach((data, i) => {
        console.log(kleur.cyan(data))
      })
      console.log(kleur.blue('Description:'), kleur.cyan(srcDescription))
      console.log(kleur.yellow('The cross-chain proposal needs to be submitted on the hub chain.'))
    }
  } catch (error: any) {
    console.error(kleur.red('Error preparing cross-chain proposal:'), error)
  }
}

/**
 * Generate a formatted description for a fleet deployment proposal
 */
function generateProposalDescription(
  deployedFleet: FleetContracts,
  fleetDefinition: FleetConfig,
  deployedArkAddresses: Address[],
  bufferArkAddress: Address,
): string {
  return `# Fleet Deployment: ${fleetDefinition.fleetName}

## Summary
This proposal activates the ${fleetDefinition.fleetName} Fleet (${fleetDefinition.symbol}).

## Technical Details
- Fleet Commander: ${deployedFleet.fleetCommander.address}
- Buffer Ark: ${bufferArkAddress}
- Number of Arks: ${deployedArkAddresses.length}

## Actions
1. Add Fleet to Harbor Command
2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
3. Add ${deployedArkAddresses.length} Arks to the Fleet

## Fleet Configuration
- Deposit Cap: ${fleetDefinition.depositCap}
- Initial Minimum Buffer Balance: ${fleetDefinition.initialMinimumBufferBalance}
- Initial Rebalance Cooldown: ${fleetDefinition.initialRebalanceCooldown}
- Initial Tip Rate: ${fleetDefinition.initialTipRate}
`
}

// Execute the deployFleet function and handle any errors
deployFleet().catch((error) => {
  console.error(kleur.red('Error during fleet deployment:'))
  console.error(error)
  process.exit(1)
})
