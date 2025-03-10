import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address, encodeFunctionData } from 'viem'
import { TipJarContracts, createTipJarModule } from '../ignition/modules/tipjar'
import { BaseConfig } from '../types/config-types'
import { GOVERNOR_ROLE, HUB_CHAIN_NAME } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'

interface TipStream {
  recipient: Address
  allocation: string
  minTerm: string
}

interface TipStreamsConfig {
  tipStreams: TipStream[]
}

/**
 * Deploys the TipJar contract and updates the ConfigurationManager.
 */
async function redeployTipJar() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Check if using Tenderly virtual testnet
  const isTenderly = warnIfTenderlyVirtualTestnet(
    'Deployments on Tenderly virtual testnets are temporary and will be lost when the session ends.',
  )

  if (isTenderly) {
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

  // Ask about using bummer config
  const useBummerConfig = await promptForConfigType()

  // Load the configuration for the current network
  const config = getConfigByNetwork(
    network,
    { common: true, core: true, gov: true },
    useBummerConfig,
  )

  // Determine if this is a hub or satellite chain
  const isHubChain = network === HUB_CHAIN_NAME
  console.log(kleur.blue('Chain Type:'), isHubChain ? kleur.cyan('Hub') : kleur.cyan('Satellite'))

  // Load tip streams configuration
  const tipStreamsConfig = await loadTipStreamsConfig()

  // Display summary and get confirmation
  if (await confirmDeployment(tipStreamsConfig)) {
    // Deploy the TipJar contract
    const deployedTipJar = await deployTipJarContract(config)
    console.log(kleur.green().bold('TipJar deployed successfully!'))
    console.log(kleur.yellow('TipJar Address:'), kleur.cyan(deployedTipJar.tipJar.address))

    // Check if deployer has governor role
    const protocolAccessManager = await hre.viem.getContractAt(
      'ProtocolAccessManager',
      config.deployedContracts.gov.protocolAccessManager.address as Address,
    )
    const [deployer] = await hre.viem.getWalletClients()
    const hasGovernorRole = await protocolAccessManager.read.hasRole([
      GOVERNOR_ROLE,
      deployer.account.address,
    ])

    if (hasGovernorRole) {
      // Direct execution path
      console.log(kleur.green('Deployer has governor role. Executing actions directly...'))

      // Update ConfigurationManager with new TipJar address
      await updateConfigurationManager(deployedTipJar.tipJar.address, config)

      // Set up tip streams
      await setupTipStreams(deployedTipJar.tipJar.address, tipStreamsConfig)

      console.log(kleur.green().bold('\nTipJar deployment and setup completed successfully!'))
    } else {
      // Governance proposal path
      console.log(
        kleur.yellow('Deployer does not have governor role. Creating governance proposal...'),
      )

      if (isHubChain) {
        await createHubGovernanceProposal(
          deployedTipJar.tipJar.address,
          config,
          tipStreamsConfig,
          useBummerConfig,
        )
      } else {
        const hubConfig = getConfigByNetwork(
          HUB_CHAIN_NAME,
          { common: true, core: true, gov: true },
          useBummerConfig,
        )
        const targetConfig = config
        await createSatelliteGovernanceProposal(
          deployedTipJar.tipJar.address,
          hubConfig,
          targetConfig,
          tipStreamsConfig,
          useBummerConfig,
          isTenderly,
        )
      }
    }

    return deployedTipJar
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }
}

/**
 * Loads the tip streams configuration from the JSON file.
 * @returns {Promise<TipStreamsConfig>} The tip streams configuration.
 */
async function loadTipStreamsConfig(): Promise<TipStreamsConfig> {
  try {
    const configPath = path.resolve(__dirname, '../launch-config/tip-streams.json')
    const tipStreamsConfig: TipStreamsConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'))

    if (!tipStreamsConfig.tipStreams || tipStreamsConfig.tipStreams.length === 0) {
      console.log(kleur.yellow('Warning: No tip streams configured in tip-streams.json.'))
    } else {
      console.log(kleur.green(`Found ${tipStreamsConfig.tipStreams.length} tip streams in config.`))
    }

    return tipStreamsConfig
  } catch (error) {
    console.error(kleur.red('Error loading tip streams configuration:'), error)
    throw error
  }
}

/**
 * Deploys the TipJar contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<TipJarContracts>} The deployed TipJar contract.
 */
async function deployTipJarContract(config: BaseConfig): Promise<TipJarContracts> {
  console.log(kleur.cyan().bold('Deploying TipJar Contract...'))

  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  // Get token from configuration (SUMMER token for TipJar)
  const tokenAddress = config.deployedContracts.gov.summerToken.address
  if (!tokenAddress) {
    throw new Error('SUMMER token address not found in configuration')
  }

  console.log(kleur.yellow('SUMMER Token Address:'), kleur.cyan(tokenAddress))

  // Deploy TipJar module
  return (await hre.ignition.deploy(
    createTipJarModule({
      token: tokenAddress as Address,
    }),
    {
      deploymentId,
    },
  )) as TipJarContracts
}

/**
 * Updates the ConfigurationManager with the new TipJar address.
 * @param {Address} tipJarAddress - The address of the deployed TipJar.
 * @param {BaseConfig} config - The configuration object.
 */
async function updateConfigurationManager(
  tipJarAddress: Address,
  config: BaseConfig,
): Promise<void> {
  console.log(kleur.cyan().bold('\nUpdating ConfigurationManager...'))

  try {
    const configManagerAddress = config.deployedContracts.core.configurationManager
      .address as Address

    if (!configManagerAddress) {
      throw new Error('ConfigurationManager address not found in configuration')
    }

    console.log(kleur.yellow('ConfigurationManager Address:'), kleur.cyan(configManagerAddress))

    const configManager = await hre.viem.getContractAt(
      'ConfigurationManager' as string,
      configManagerAddress,
    )
    const [deployer] = await hre.viem.getWalletClients()
    const publicClient = await hre.viem.getPublicClient()

    // Get current TipJar address
    const currentTipJar = await configManager.read.tipJar()
    console.log(kleur.yellow('Current TipJar Address:'), kleur.cyan(currentTipJar as Address))
    console.log(kleur.yellow('New TipJar Address:'), kleur.cyan(tipJarAddress))

    // Update TipJar in ConfigurationManager
    const hash = await configManager.write.setTipJar([tipJarAddress], { account: deployer.account })
    await publicClient.waitForTransactionReceipt({ hash })

    console.log(kleur.green('✅ Successfully updated TipJar in ConfigurationManager'))
  } catch (error) {
    console.error(kleur.red('Error updating ConfigurationManager:'), error)
    throw error
  }
}

/**
 * Sets up tip streams according to the configuration.
 * @param {Address} tipJarAddress - The address of the deployed TipJar contract.
 * @param {TipStreamsConfig} tipStreamsConfig - The tip streams configuration.
 */
async function setupTipStreams(
  tipJarAddress: Address,
  tipStreamsConfig: TipStreamsConfig,
): Promise<void> {
  console.log(kleur.cyan().bold('\nSetting up tip streams...'))

  try {
    if (!tipStreamsConfig.tipStreams || tipStreamsConfig.tipStreams.length === 0) {
      console.log(kleur.yellow('No tip streams configured. Skipping setup.'))
      return
    }

    // Get the TipJar contract instance
    const tipJar = await hre.viem.getContractAt('TipJar' as string, tipJarAddress)
    const [deployer] = await hre.viem.getWalletClients()
    const publicClient = await hre.viem.getPublicClient()

    console.log(kleur.yellow(`Setting up ${tipStreamsConfig.tipStreams.length} tip streams...`))

    // Add each tip stream
    for (const stream of tipStreamsConfig.tipStreams) {
      console.log(
        kleur.yellow(
          `Adding stream: ${stream.recipient} - ${stream.allocation} - Min Term: ${stream.minTerm} seconds`,
        ),
      )

      try {
        const hash = await tipJar.write.addTipStream(
          [stream.recipient, stream.allocation, stream.minTerm],
          { account: deployer.account },
        )

        await publicClient.waitForTransactionReceipt({ hash })
        console.log(kleur.green(`✅ Successfully added tip stream for ${stream.recipient}`))
      } catch (error) {
        console.error(kleur.red(`Failed to add tip stream for ${stream.recipient}:`), error)
      }
    }

    console.log(kleur.green().bold('All tip streams set up successfully!'))
  } catch (error) {
    console.error(kleur.red('Error setting up tip streams:'), error)
    throw error
  }
}

/**
 * Creates a governance proposal on the hub chain.
 * @param {Address} tipJarAddress - The address of the deployed TipJar.
 * @param {BaseConfig} config - The configuration object.
 * @param {TipStreamsConfig} tipStreamsConfig - The tip streams configuration.
 * @param {boolean} useBummerConfig - Whether to use bummer config.
 */
async function createHubGovernanceProposal(
  tipJarAddress: Address,
  config: BaseConfig,
  tipStreamsConfig: TipStreamsConfig,
  useBummerConfig: boolean,
): Promise<void> {
  console.log(kleur.cyan().bold('\nCreating hub governance proposal...'))

  try {
    const configManagerAddress = config.deployedContracts.core.configurationManager
      .address as Address
    const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address

    if (!configManagerAddress || !governorAddress) {
      throw new Error('Required contract addresses not found in configuration')
    }

    // Generate calldata for setting TipJar in ConfigurationManager
    const configManager = await hre.viem.getContractAt(
      'ConfigurationManager' as string,
      configManagerAddress,
    )

    const setTipJarCalldata = encodeFunctionData({
      abi: configManager.abi,
      functionName: 'setTipJar',
      args: [tipJarAddress],
    })

    // Generate calldata for setting up tip streams
    const tipJar = await hre.viem.getContractAt('TipJar' as string, tipJarAddress)
    const tipStreamCalldatas: { target: Address; value: bigint; calldata: string }[] = []

    if (tipStreamsConfig.tipStreams && tipStreamsConfig.tipStreams.length > 0) {
      for (const stream of tipStreamsConfig.tipStreams) {
        const addTipStreamCalldata = encodeFunctionData({
          abi: tipJar.abi,
          functionName: 'addTipStream',
          args: [stream.recipient, stream.allocation, stream.minTerm],
        })

        tipStreamCalldatas.push({
          target: tipJarAddress,
          value: 0n,
          calldata: addTipStreamCalldata,
        })
      }
    }

    // Combine all calldatas
    const targets: Address[] = [
      configManagerAddress,
      ...tipStreamCalldatas.map((data) => data.target),
    ]
    const values: bigint[] = [0n, ...tipStreamCalldatas.map((data) => data.value)]
    const calldatas: string[] = [
      setTipJarCalldata,
      ...tipStreamCalldatas.map((data) => data.calldata),
    ]

    // Generate proposal description
    const description = `
      # TipJar Update
      
      This proposal:
      1. Sets the new TipJar address (${tipJarAddress}) in the ConfigurationManager
      ${
        tipStreamCalldatas.length > 0
          ? `2. Sets up ${tipStreamCalldatas.length} tip streams in the new TipJar`
          : ''
      }
    `.trim()

    console.log(kleur.yellow('Proposal Summary:'))
    console.log(kleur.yellow(description))
    console.log(kleur.yellow('Targets:'), targets)
    console.log(
      kleur.yellow('Values:'),
      values.map((v) => v.toString()),
    )
    console.log(kleur.yellow('Calldata Count:'), calldatas.length)

    // Create the proposal
    const governor = await hre.viem.getContractAt('SummerGovernor' as string, governorAddress)
    const [deployer] = await hre.viem.getWalletClients()

    const hash = await governor.write.propose([targets, values, calldatas, description], {
      account: deployer.account,
    })

    const publicClient = await hre.viem.getPublicClient()
    const receipt = await publicClient.waitForTransactionReceipt({ hash })

    console.log(kleur.green('✅ Successfully created hub governance proposal'))
    console.log(kleur.yellow('Transaction Hash:'), kleur.cyan(receipt.transactionHash))

    // Extract proposal ID from events
    try {
      const proposalCreatedLog = receipt.logs.find((log) => {
        // Match ProposalCreated event topic
        return (
          log.topics[0] === '0x7d84a6263ae0d98d3329bd7b46bb4e8d6f98cd35a7adb45c274c8b7fd5ebd5e0'
        )
      })

      if (proposalCreatedLog) {
        console.log(kleur.green('Proposal created successfully!'))
        // Display information about how to vote on this proposal
        console.log(kleur.yellow('\nTo view and vote on this proposal:'))
        console.log(kleur.cyan('1. Wait for the voting delay period to pass'))
        console.log(kleur.cyan('2. Use the Governor contract to cast your votes'))
      }
    } catch (error) {
      console.log(
        kleur.yellow('Could not extract proposal ID from logs. Check the transaction for details.'),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error creating hub governance proposal:'), error)
    throw error
  }
}

/**
 * Creates a governance proposal on a satellite chain.
 * @param {Address} tipJarAddress - The address of the deployed TipJar.
 * @param {BaseConfig} config - The configuration object.
 * @param {TipStreamsConfig} tipStreamsConfig - The tip streams configuration.
 * @param {boolean} useBummerConfig - Whether to use bummer config.
 * @param {boolean} isTenderly - Whether we're on a Tenderly network.
 */
async function createSatelliteGovernanceProposal(
  tipJarAddress: Address,
  hubConfig: BaseConfig,
  targetConfig: BaseConfig,
  tipStreamsConfig: TipStreamsConfig,
  useBummerConfig: boolean,
  isTenderly: boolean,
): Promise<void> {
  console.log(kleur.cyan().bold('\nCreating satellite governance proposal...'))
  console.log(kleur.yellow('This requires a cross-chain message to be relayed to the hub chain.'))

  try {
    const configManagerAddress = targetConfig.deployedContracts.core.configurationManager
      .address as Address
    const satelliteGovernorAddress = targetConfig.deployedContracts.gov.summerGovernor
      .address as Address

    if (!configManagerAddress || !satelliteGovernorAddress) {
      throw new Error('Required contract addresses not found in configuration')
    }

    // Generate calldata for setting TipJar in ConfigurationManager
    const configManager = await hre.viem.getContractAt(
      'ConfigurationManager' as string,
      configManagerAddress,
    )
    const setTipJarCalldata = encodeFunctionData({
      abi: configManager.abi,
      functionName: 'setTipJar',
      args: [tipJarAddress],
    })

    // Generate calldata for setting up tip streams
    const tipJar = await hre.viem.getContractAt('TipJar' as string, tipJarAddress)
    const tipStreamCalldatas: { target: Address; value: bigint; calldata: string }[] = []

    if (tipStreamsConfig.tipStreams && tipStreamsConfig.tipStreams.length > 0) {
      for (const stream of tipStreamsConfig.tipStreams) {
        const addTipStreamCalldata = encodeFunctionData({
          abi: tipJar.abi,
          functionName: 'addTipStream',
          args: [stream.recipient, stream.allocation, stream.minTerm],
        })

        tipStreamCalldatas.push({
          target: tipJarAddress,
          value: 0n,
          calldata: addTipStreamCalldata,
        })
      }
    }

    // Combine all calldatas
    const targets: Address[] = [
      configManagerAddress,
      ...tipStreamCalldatas.map((data) => data.target),
    ]
    const values: bigint[] = [0n, ...tipStreamCalldatas.map((data) => data.value)]
    const calldatas: string[] = [
      setTipJarCalldata,
      ...tipStreamCalldatas.map((data) => data.calldata),
    ]

    // Generate proposal description
    const description = `
      # TipJar Update on Satellite Chain
      
      This proposal:
      1. Sets the new TipJar address (${tipJarAddress}) in the ConfigurationManager
      ${
        tipStreamCalldatas.length > 0
          ? `2. Sets up ${tipStreamCalldatas.length} tip streams in the new TipJar`
          : ''
      }
    `.trim()

    console.log(kleur.yellow('Proposal Summary:'))
    console.log(kleur.yellow(description))
    console.log(kleur.yellow('Targets:'), targets)
    console.log(
      kleur.yellow('Values:'),
      values.map((v) => v.toString()),
    )
    console.log(kleur.yellow('Calldata Count:'), calldatas.length)

    // Create the proposal through satellite governor
    const satelliteGov = await hre.viem.getContractAt('SatelliteGovRelay', satelliteGovernorAddress)
    const [deployer] = await hre.viem.getWalletClients()

    if (isTenderly) {
      console.log(
        kleur.yellow(
          'Note: On Tenderly, cross-chain messaging simulation might not work properly.',
        ),
      )
    }

    const hash = await satelliteGov.write.createProposal(
      [targets, values, calldatas, description],
      { account: deployer.account },
    )

    const publicClient = await hre.viem.getPublicClient()
    const receipt = await publicClient.waitForTransactionReceipt({ hash })

    console.log(kleur.green('✅ Successfully initiated satellite governance proposal'))
    console.log(kleur.yellow('Transaction Hash:'), kleur.cyan(receipt.transactionHash))
    console.log(kleur.yellow('\nImportant:'))
    console.log(kleur.cyan('- The cross-chain message must be relayed to the hub chain'))
    console.log(
      kleur.cyan('- After relay, the proposal will appear in the hub governor for voting'),
    )
  } catch (error) {
    console.error(kleur.red('Error creating satellite governance proposal:'), error)
    throw error
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {TipStreamsConfig} tipStreamsConfig - The tip streams configuration.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(tipStreamsConfig: TipStreamsConfig): Promise<boolean> {
  console.log(kleur.cyan().bold('\nSummary of TipJar Deployment:'))
  console.log(kleur.yellow('TipJar will be redeployed with the following configuration:'))

  if (tipStreamsConfig.tipStreams && tipStreamsConfig.tipStreams.length > 0) {
    console.log(kleur.yellow(`Tip Streams (${tipStreamsConfig.tipStreams.length}):`))
    tipStreamsConfig.tipStreams.forEach((stream, index) => {
      console.log(kleur.yellow(`  ${index + 1}. Recipient: ${stream.recipient}`))
      console.log(kleur.yellow(`     Allocation: ${stream.allocation}`))
      console.log(kleur.yellow(`     Min Term: ${stream.minTerm} seconds`))
    })
  } else {
    console.log(kleur.yellow('No tip streams configured.'))
  }

  return await continueDeploymentCheck()
}

// Execute the script
redeployTipJar().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { redeployTipJar }
