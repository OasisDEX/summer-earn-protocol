import fs from 'fs'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, createWalletClient, encodeAbiParameters, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { arbitrum, base, mainnet, optimism } from 'viem/chains'
import { RPC_URL_MAP } from '../common/chain-config-map'
import { promptForFleetDeploymentOutput } from '../fleets/fleet-deployment-helpers'
import { getChainPublicClient } from '../helpers/client-by-chain-helper'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getHubChain } from '../helpers/get-hub-chain'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from '../helpers/tenderly-helpers'
import { createUnifiedLzConfigProposal } from './helpers/bridge-governance-helper'
import { checkLzAuthorization } from './helpers/lz-authorization-helper'
import { LZ_ENDPOINT_ABI } from './lz-endpoint-abi'

// Interface for LayerZero configuration
interface LzEndpointConfig {
  lzEndpoint: string
  lzExecutor: string
  sendUln302: string
  receiveUln302: string
  eID: string
  dvns: Record<string, Record<string, string>>
}

// Interface for tracking configuration attempts
interface ConfigurationAttempt {
  sourceChain: string
  targetChain: string
  oAppType: 'summerToken' | 'summerGovernor'
  oAppAddress: Address
  directExecution: boolean
  success: boolean
  error?: string
  lzEndpointAddress: Address
  sendLibraryAddress: Address
  receiveLibraryAddress: Address
  sendConfigParams: any[]
  receiveConfigParams: any[]
}

/**
 * Get all chains in the ecosystem with deployed contracts
 */
async function getDeployedChains(useBummerConfig: boolean): Promise<string[]> {
  // List of chains that might have deployed contracts
  const potentialChains = ['mainnet', 'base', 'arbitrum', 'sonic', 'optimism']
  const deployedChains: string[] = []

  for (const chain of potentialChains) {
    try {
      const config = getConfigByNetwork(chain, { gov: true }, useBummerConfig)
      // Check if SummerToken exists on this chain as a basic deployment check
      if (config.deployedContracts?.gov?.summerToken?.address) {
        deployedChains.push(chain)
      }
    } catch (error) {
      // Skip chains without config or deployments
      continue
    }
  }

  return deployedChains
}

/**
 * Create route configuration parameters
 */
async function createRouteConfiguration(
  sourceChain: string,
  targetChain: string,
  oAppType: 'summerToken' | 'summerGovernor',
  useBummerConfig: boolean,
): Promise<{
  oAppAddress: Address
  lzEndpointAddress: Address
  sendLibraryAddress: Address
  receiveLibraryAddress: Address
  sendConfigParams: any[]
  receiveConfigParams: any[]
}> {
  // Get source chain configuration
  const sourceConfig = getConfigByNetwork(sourceChain, { gov: true, common: true }, useBummerConfig)

  // Get target chain configuration
  const targetConfig = getConfigByNetwork(targetChain, { common: true }, useBummerConfig)

  // Determine OApp address based on type
  let oAppAddress: Address
  if (oAppType === 'summerToken') {
    oAppAddress = sourceConfig.deployedContracts.gov.summerToken.address as Address
  } else {
    oAppAddress = sourceConfig.deployedContracts.gov.summerGovernor.address as Address
  }

  // Get LZ configuration parameters
  const lzConfig = sourceConfig.common.layerZero as unknown as LzEndpointConfig
  const targetLzConfig = targetConfig.common.layerZero as unknown as LzEndpointConfig

  // Get the LZ endpoint address
  const lzEndpointAddress = lzConfig.lzEndpoint as Address

  // Get the LZ executor addresses
  const sendLibraryAddress = lzConfig.sendUln302 as Address
  const receiveLibraryAddress = lzConfig.receiveUln302 as Address

  // Target chain EID
  const targetChainEid = Number(targetLzConfig.eID)

  // Validate that we have DVNs in config
  if (!lzConfig.dvns || !lzConfig.dvns[targetChain as keyof typeof lzConfig.dvns]) {
    throw new Error(`Missing DVN configuration for route from ${sourceChain} to ${targetChain}`)
  }

  // Get DVNs from config
  const dvns = lzConfig.dvns[targetChain as keyof typeof lzConfig.dvns]

  // Ensure all required addresses are available
  if (!lzConfig.lzExecutor || !dvns.lzLabs || !dvns.stargate) {
    throw new Error(
      `Missing required contract addresses in config for ${sourceChain} -> ${targetChain}`,
    )
  }

  // ----------------- SEND CONFIG -----------------
  // Encode executor config
  const executorConfig = {
    maxMessageSize: 10000, // Default max message size
    executorAddress: lzConfig.lzExecutor as Address,
  }

  // Encode ExecutorConfig (CONFIG_TYPE_EXECUTOR = 1)
  const encodedExecutorConfig = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'maxMessageSize', type: 'uint32' },
          { name: 'executorAddress', type: 'address' },
        ],
      },
    ],
    [executorConfig],
  )

  // Encode ULN receive config for DVNs
  const dvnAddresses = [dvns.lzLabs as Address, dvns.stargate as Address].sort()

  const ulnConfig = {
    confirmations: 15n, // Keep as bigint - this is a uint64
    requiredDVNCount: 2,
    optionalDVNCount: 0,
    optionalDVNThreshold: 0,
    requiredDVNs: dvnAddresses,
    optionalDVNs: [] as readonly Address[],
  }

  // Encode ULN Config (CONFIG_TYPE_ULN = 2)
  const encodedUlnConfig = encodeAbiParameters(
    [
      {
        type: 'tuple',
        components: [
          { name: 'confirmations', type: 'uint64' },
          { name: 'requiredDVNCount', type: 'uint8' },
          { name: 'optionalDVNCount', type: 'uint8' },
          { name: 'optionalDVNThreshold', type: 'uint8' },
          { name: 'requiredDVNs', type: 'address[]' },
          { name: 'optionalDVNs', type: 'address[]' },
        ],
      },
    ],
    [ulnConfig],
  )

  // Create send SetConfigParam array with both config types
  const sendConfigParams = [
    {
      eid: targetChainEid,
      configType: 1, // CONFIG_TYPE_EXECUTOR
      config: encodedExecutorConfig,
    },
    {
      eid: targetChainEid,
      configType: 2, // CONFIG_TYPE_ULN
      config: encodedUlnConfig,
    },
  ]

  // Create receive SetConfigParam array with only ULN config
  const receiveConfigParams = [
    {
      eid: targetChainEid,
      configType: 2, // CONFIG_TYPE_ULN
      config: encodedUlnConfig,
    },
  ]

  return {
    oAppAddress,
    lzEndpointAddress,
    sendLibraryAddress,
    receiveLibraryAddress,
    sendConfigParams,
    receiveConfigParams,
  }
}

/**
 * Try to execute a configuration directly
 */
async function tryDirectExecution(
  chain: string,
  oAppAddress: Address,
  lzEndpointAddress: Address,
  sendLibraryAddress: Address,
  receiveLibraryAddress: Address,
  sendConfigParams: any[],
  receiveConfigParams: any[],
  isNewChain: boolean = false,
  useBummerConfig: boolean = false,
): Promise<{ success: boolean; error?: string }> {
  console.log(kleur.blue(`Checking if we can directly configure OApp on ${chain}:`))

  try {
    // Get a public client for the chain - use our new helper
    const publicClient = await getChainPublicClient(chain)

    // Get the source chain configuration to access RPC URLs
    const sourceConfig = getConfigByNetwork(chain, { common: true }, useBummerConfig)

    if (!RPC_URL_MAP[chain as keyof typeof RPC_URL_MAP]) {
      return {
        success: false,
        error: `No RPC URL found for chain ${chain} in the configuration`,
      }
    }

    const rpcUrl = RPC_URL_MAP[chain as keyof typeof RPC_URL_MAP]

    // Get chain configuration from Viem based on the chain name
    let chainConfig
    try {
      // Map your chain names to Viem chain objects
      const chainMap: Record<string, any> = {
        mainnet: mainnet,
        base: base,
        arbitrum: arbitrum,
        optimism: optimism,
        sonic: {
          id: Number(sourceConfig.common.chainId),
          name: 'Sonic',
          network: 'sonic',
          nativeCurrency: { name: 'S', symbol: 'S', decimals: 18 },
          rpcUrls: {
            default: { http: [rpcUrl] },
            public: { http: [rpcUrl] },
          },
        },
        // Add any other chains as needed
      }

      chainConfig = chainMap[chain]
      if (!chainConfig) {
        return {
          success: false,
          error: `Unsupported chain: ${chain}`,
        }
      }
    } catch (error: any) {
      return {
        success: false,
        error: `Failed to get chain configuration for ${chain}: ${error.message}`,
      }
    }

    // Get wallet private key (using environment variable or config)
    let privateKey = process.env.DEPLOYER_PRIV_KEY

    if (!privateKey) {
      return {
        success: false,
        error: 'No deployer private key found. Set the DEPLOYER_PRIVATE_KEY environment variable.',
      }
    }

    // Ensure private key is properly formatted with 0x prefix
    if (!privateKey.startsWith('0x')) {
      privateKey = `0x${privateKey}`
    }

    // Create a Viem wallet client for the target chain
    const account = privateKeyToAccount(privateKey as `0x${string}`)
    const walletClient = createWalletClient({
      account,
      chain: chainConfig,
      transport: http(rpcUrl),
    })

    console.log(kleur.yellow(`  Using account: ${account.address}`))

    // Check if deployer is authorized (using our helper function)
    const { isAuthorized, delegate } = await checkLzAuthorization(
      lzEndpointAddress,
      oAppAddress,
      account.address,
      chain,
    )

    if (!isAuthorized) {
      // If this is a new chain targeting existing chains, we should throw an error
      if (isNewChain) {
        throw new Error(
          `Deployer is not authorized for OApp ${oAppAddress} on ${chain}. ` +
            `This should be configured before ownership is transferred.`,
        )
      }

      return {
        success: false,
        error: `Not authorized for OApp ${oAppAddress}. Current delegate: ${delegate}`,
      }
    }

    // Check if send config already exists
    let sendConfigNeeded = false
    for (const configParam of sendConfigParams) {
      console.log(
        kleur.yellow(`  Checking if send config type ${configParam.configType} already exists...`),
      )
      const existingConfig = await publicClient.readContract({
        address: lzEndpointAddress,
        abi: LZ_ENDPOINT_ABI,
        functionName: 'getConfig',
        args: [oAppAddress, sendLibraryAddress, configParam.eid, configParam.configType],
      })

      if (existingConfig !== configParam.config) {
        sendConfigNeeded = true
        console.log(kleur.yellow(`  Send config needs update for type ${configParam.configType}`))
      } else {
        console.log(
          kleur.green(`  Send config already set correctly for type ${configParam.configType}`),
        )
      }
    }

    // Set send config if needed
    if (sendConfigNeeded) {
      console.log(kleur.yellow(`  Setting send config on ${chain}...`))
      const sendHash = await walletClient.writeContract({
        address: lzEndpointAddress,
        abi: LZ_ENDPOINT_ABI,
        functionName: 'setConfig',
        args: [oAppAddress, sendLibraryAddress, sendConfigParams],
        chain: chainConfig,
      })

      // Wait for transaction receipt
      console.log(kleur.yellow(`  Waiting for send config transaction to be mined...`))
      await publicClient.waitForTransactionReceipt({ hash: sendHash })
      console.log(kleur.green(`  Send config transaction successful: ${sendHash}`))
    } else {
      console.log(kleur.green(`  All send configs already set correctly, skipping transaction`))
    }

    // Check if receive config already exists
    let receiveConfigNeeded = false
    for (const configParam of receiveConfigParams) {
      console.log(
        kleur.yellow(
          `  Checking if receive config type ${configParam.configType} already exists...`,
        ),
      )
      const existingConfig = await publicClient.readContract({
        address: lzEndpointAddress,
        abi: LZ_ENDPOINT_ABI,
        functionName: 'getConfig',
        args: [oAppAddress, receiveLibraryAddress, configParam.eid, configParam.configType],
      })

      if (existingConfig !== configParam.config) {
        receiveConfigNeeded = true
        console.log(
          kleur.yellow(`  Receive config needs update for type ${configParam.configType}`),
        )
      } else {
        console.log(
          kleur.green(`  Receive config already set correctly for type ${configParam.configType}`),
        )
      }
    }

    // Set receive config if needed
    if (receiveConfigNeeded) {
      console.log(kleur.yellow(`  Setting receive config on ${chain}...`))
      const receiveHash = await walletClient.writeContract({
        address: lzEndpointAddress,
        abi: LZ_ENDPOINT_ABI,
        functionName: 'setConfig',
        args: [oAppAddress, receiveLibraryAddress, receiveConfigParams],
        chain: chainConfig,
      })

      // Wait for transaction receipt
      console.log(kleur.yellow(`  Waiting for receive config transaction to be mined...`))
      await publicClient.waitForTransactionReceipt({ hash: receiveHash })
      console.log(kleur.green(`  Receive config transaction successful: ${receiveHash}`))
    } else {
      console.log(kleur.green(`  All receive configs already set correctly, skipping transaction`))
    }

    return { success: true }
  } catch (error: any) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }
  }
}

/**
 * Group configuration attempts by source chain
 */
function groupConfigurationsByChain(
  configs: ConfigurationAttempt[],
): Record<string, ConfigurationAttempt[]> {
  const grouped: Record<string, ConfigurationAttempt[]> = {}

  for (const config of configs) {
    if (!grouped[config.sourceChain]) {
      grouped[config.sourceChain] = []
    }
    grouped[config.sourceChain].push(config)
  }

  return grouped
}

/**
 * Create governance proposals for failed configurations
 */
async function createGovernanceProposals(
  groupedConfigs: Record<string, ConfigurationAttempt[]>,
  useBummerConfig: boolean,
  newChainName: string,
  discourseURL: string = '',
) {
  console.log(kleur.cyan('\n📝 Creating governance proposals for failed configurations:'))

  // Separate hub chain configs from other chains
  const hubChain = getHubChain()
  const hubChainConfigs = groupedConfigs[hubChain] || []

  // Collect all non-hub chain configs
  const nonHubChainConfigs: ConfigurationAttempt[] = []
  for (const [chain, configs] of Object.entries(groupedConfigs)) {
    if (chain !== hubChain) {
      nonHubChainConfigs.push(...configs)
    }
  }

  // Only proceed if we have at least one configuration
  if (hubChainConfigs.length === 0 && nonHubChainConfigs.length === 0) {
    console.log(kleur.yellow('No configurations to include in proposals.'))
    return
  }

  // Prompt for fleet deployment selection
  const selectedFleetPath = await promptForFleetDeploymentOutput(newChainName)
  let fleetDeployments

  if (selectedFleetPath) {
    try {
      // Read the selected fleet deployment file
      const fleetData = JSON.parse(fs.readFileSync(selectedFleetPath, 'utf8'))
      console.log('fleetData', fleetData)
      fleetDeployments = processFleetDeploymentData(fleetData, newChainName)
      console.log(
        kleur.green(`Loaded fleet deployment data with ${fleetDeployments.length} fleets`),
      )
    } catch (error) {
      console.error(kleur.red(`Error loading fleet deployment file: ${error}`))
    }
  } else {
    console.log(kleur.yellow(`No fleet deployments selected for ${newChainName}`))
  }

  // Generate peer configurations for existing chains to new chain
  console.log(kleur.blue('\nGenerating peer configurations from existing chains to new chain...'))

  const peerConfigurations = await generatePeerConfigurations(newChainName, useBummerConfig)

  if (peerConfigurations.tokenPeers.length > 0 || peerConfigurations.governorPeers.length > 0) {
    console.log(
      kleur.green(
        `Generated ${peerConfigurations.tokenPeers.length} token peers and ${peerConfigurations.governorPeers.length} governor peers`,
      ),
    )
  } else {
    console.log(kleur.yellow('No peer configurations generated'))
  }

  console.log(
    kleur.yellow(
      `\nCreating aggregated proposal with ${hubChainConfigs.length} hub chain configs and ${nonHubChainConfigs.length} cross-chain configs and peer configurations`,
    ),
  )

  try {
    // Create a single proposal containing both hub chain and cross-chain actions, plus peering
    await createUnifiedLzConfigProposal(
      hubChainConfigs,
      nonHubChainConfigs,
      useBummerConfig,
      newChainName,
      discourseURL,
      undefined, // No existing proposal
      fleetDeployments, // Pass fleet deployments info
      peerConfigurations, // Pass peer configurations
    )
  } catch (error: any) {
    console.error(kleur.red(`Error creating unified proposal:`))
    console.error(error instanceof Error ? error.message : String(error))
  }
}

/**
 * Generate peer configurations for existing chains to connect to the new chain
 */
async function generatePeerConfigurations(newChainName: string, useBummerConfig: boolean) {
  console.log(kleur.blue(`Generating peer configurations for existing chains to ${newChainName}`))

  // Get all chains that have deployed contracts
  const deployedChains = await getDeployedChains(useBummerConfig)
  const hubChain = getHubChain()

  // Get config for the new chain
  const newChainConfig = getConfigByNetwork(
    newChainName,
    { common: true, gov: true },
    useBummerConfig,
  )

  // Initialize peer configurations
  const tokenPeers: Array<{
    sourceChain: string
    eid: number
    address: string
  }> = []

  const governorPeers: Array<{
    sourceChain: string
    eid: number
    address: string
  }> = []

  // Get the EID for the new chain
  const newChainEid = Number(newChainConfig.common.layerZero.eID)

  // Get the contract addresses for the new chain
  const newChainTokenAddress = newChainConfig.deployedContracts?.gov?.summerToken?.address
  const newChainGovernorAddress = newChainConfig.deployedContracts?.gov?.summerGovernor?.address

  if (!newChainTokenAddress || !newChainGovernorAddress) {
    console.log(kleur.red(`Missing contract addresses for ${newChainName}`))
    return { tokenPeers: [], governorPeers: [] }
  }

  // For each deployed chain, create peer configurations
  for (const sourceChain of deployedChains) {
    if (sourceChain === newChainName) continue // Skip self-connections

    console.log(kleur.yellow(`Generating peer config for ${sourceChain} -> ${newChainName}`))

    // Get the source chain config
    const sourceConfig = getConfigByNetwork(
      sourceChain,
      { common: true, gov: true },
      useBummerConfig,
    )

    // Create token peer config - all chains need to peer with all other chains
    tokenPeers.push({
      sourceChain,
      eid: newChainEid,
      address: newChainTokenAddress,
    })

    // Create governor peer config - only hub needs to peer with satellites
    // and satellites need to peer with hub
    const isSourceHub = sourceChain === hubChain
    const isNewChainHub = newChainName === hubChain

    if (isSourceHub || isNewChainHub) {
      governorPeers.push({
        sourceChain,
        eid: newChainEid,
        address: newChainGovernorAddress,
      })
    } else {
      console.log(
        kleur.blue(
          `Skipping governor peer config for satellite-to-satellite: ${sourceChain} -> ${newChainName}`,
        ),
      )
    }
  }

  return { tokenPeers, governorPeers }
}

/**
 * Process fleet deployment data from the selected file
 */
function processFleetDeploymentData(
  fleetData: any,
  chainName: string,
): Array<{
  name: string
  fleetCommander: Address
  bufferArk: Address
  arks: Address[]
  config?: {
    depositCap?: string
    minimumBufferBalance?: string
    rebalanceCooldown?: string
    tipRate?: string
  }
}> {
  const fleets: Array<{
    name: string
    fleetCommander: Address
    bufferArk: Address
    arks: Address[]
    config?: {
      depositCap?: string
      minimumBufferBalance?: string
      rebalanceCooldown?: string
      tipRate?: string
    }
  }> = []

  // Check if we have a fleets array in the data
  if (Array.isArray(fleetData.fleets)) {
    // Process each fleet in the array
    for (const fleet of fleetData.fleets) {
      fleets.push({
        name: fleet.fleetName || fleet.name || `Fleet on ${chainName}`,
        fleetCommander: fleet.fleetCommander || fleet.commanderAddress || fleet.fleetAddress,
        bufferArk: fleet.bufferArk || fleet.bufferArkAddress,
        arks: Array.isArray(fleet.arks)
          ? fleet.arks
          : Array.isArray(fleet.arkAddresses)
            ? fleet.arkAddresses
            : [],
        config: {
          depositCap: fleet.config?.depositCap || fleet.depositCap,
          minimumBufferBalance:
            fleet.config?.minimumBufferBalance ||
            fleet.minimumBufferBalance ||
            fleet.initialMinimumBufferBalance,
          rebalanceCooldown:
            fleet.config?.rebalanceCooldown ||
            fleet.rebalanceCooldown ||
            fleet.initialRebalanceCooldown,
          tipRate: fleet.config?.tipRate || fleet.tipRate || fleet.initialTipRate,
        },
      })
    }
  } else {
    // Single fleet data
    fleets.push({
      name: fleetData.fleetName || fleetData.name || `Fleet on ${chainName}`,
      fleetCommander:
        fleetData.fleetCommander || fleetData.commanderAddress || fleetData.fleetAddress,
      bufferArk: fleetData.bufferArk || fleetData.bufferArkAddress,
      arks: Array.isArray(fleetData.arks)
        ? fleetData.arks
        : Array.isArray(fleetData.arkAddresses)
          ? fleetData.arkAddresses
          : [],
      config: {
        depositCap: fleetData.config?.depositCap || fleetData.depositCap,
        minimumBufferBalance:
          fleetData.config?.minimumBufferBalance ||
          fleetData.minimumBufferBalance ||
          fleetData.initialMinimumBufferBalance,
        rebalanceCooldown:
          fleetData.config?.rebalanceCooldown ||
          fleetData.rebalanceCooldown ||
          fleetData.initialRebalanceCooldown,
        tipRate: fleetData.config?.tipRate || fleetData.tipRate || fleetData.initialTipRate,
      },
    })
  }

  return fleets
}

/**
 * Configure LayerZero for a new chain with all required routes
 */
async function configureNewChainLayerZero(useBummerConfigOverride?: boolean) {
  // Check if using Tenderly virtual testnet
  const isTenderly = warnIfTenderlyVirtualTestnet(
    'Configurations on Tenderly virtual testnets are temporary and will be lost when the session ends.',
  )

  if (isTenderly) {
    const response = await prompts({
      type: 'confirm',
      name: 'continue',
      message: 'Do you want to continue with configuration on this Tenderly virtual testnet?',
      initial: false,
    })

    if (!response.continue) {
      console.log(kleur.red('Configuration cancelled.'))
      return
    }
  }

  // If bummerConfig was specified via command line, use it
  // Otherwise, prompt the user
  let useBummerConfig = !!useBummerConfigOverride
  if (useBummerConfigOverride === undefined) {
    useBummerConfig = await promptForConfigType()
  } else {
    console.log(
      kleur.blue('Using'),
      kleur.cyan(useBummerConfig ? 'bummer' : 'default'),
      kleur.blue('configuration.'),
    )
  }

  // Get all chains that have deployed contracts
  const deployedChains = await getDeployedChains(useBummerConfig)
  console.log(
    kleur.blue('Detected chains with deployments:'),
    kleur.cyan(deployedChains.join(', ')),
  )

  // Ask for the new chain to configure
  const { newChain } = await prompts({
    type: 'text',
    name: 'newChain',
    message: 'Enter the name of the new chain to configure:',
    validate: (value) => {
      if (!value) return 'Chain name is required'
      if (value === getHubChain()) return 'Cannot use hub chain as new chain'
      try {
        getConfigByNetwork(value, { common: true }, useBummerConfig)
        return true
      } catch (error) {
        return `Configuration not found for chain ${value}`
      }
    },
  })

  console.log(kleur.cyan(`\n🔄 Configuring LayerZero for new chain: ${newChain}\n`))

  // Track all configuration attempts
  const configurationAttempts: ConfigurationAttempt[] = []

  // Phase 1: Configure SummerToken routes
  console.log(kleur.cyan('\n--- Phase 1: Configuring SummerToken Routes ---'))
  console.log(kleur.cyan('SummerToken requires all chains to be connected with each other.'))

  // Create routes from all deployed chains to the new chain
  for (const sourceChain of deployedChains) {
    if (sourceChain === newChain) continue // Skip self-connections

    console.log(kleur.yellow(`\nConfiguring ${sourceChain} → ${newChain} for SummerToken...`))
    // Create the configuration parameters
    const {
      oAppAddress,
      lzEndpointAddress,
      sendLibraryAddress,
      receiveLibraryAddress,
      sendConfigParams,
      receiveConfigParams,
    } = await createRouteConfiguration(sourceChain, newChain, 'summerToken', useBummerConfig)
    try {
      console.log(kleur.yellow(`  Attempting direct execution...`))
      const { success, error } = await tryDirectExecution(
        sourceChain,
        oAppAddress,
        lzEndpointAddress,
        sendLibraryAddress,
        receiveLibraryAddress,
        sendConfigParams,
        receiveConfigParams,
        false, // Not a new chain targeting existing
        useBummerConfig,
      )

      if (!success) {
        throw new Error(
          `Failed to configure ${sourceChain} → ${newChain}: ${error}\n` +
            `Likely requires governance proposal to be created.`,
        )
      }

      // Record the attempt
      configurationAttempts.push({
        sourceChain,
        targetChain: newChain,
        oAppType: 'summerToken',
        oAppAddress,
        directExecution: true,
        success,
        error,
        lzEndpointAddress,
        sendLibraryAddress,
        receiveLibraryAddress,
        sendConfigParams,
        receiveConfigParams,
      })

      if (success) {
        console.log(kleur.green(`  ✓ Successfully configured ${sourceChain} → ${newChain}`))
      } else {
        console.log(kleur.red(`  ❌ Direct execution failed: ${error}`))
      }
    } catch (error: any) {
      console.log(kleur.red(`  ❌ Error configuring route: ${error.message}`))
      // Still record the attempt
      configurationAttempts.push({
        sourceChain,
        targetChain: newChain,
        oAppType: 'summerToken',
        oAppAddress,
        directExecution: false,
        success: false,
        error: error.message,
        lzEndpointAddress,
        sendLibraryAddress,
        receiveLibraryAddress,
        sendConfigParams,
        receiveConfigParams,
      })
    }
  }

  // Create routes from the new chain to all deployed chains
  console.log(kleur.yellow(`\nConfiguring routes from ${newChain} to all other chains...`))
  for (const targetChain of deployedChains) {
    if (targetChain === newChain) continue // Skip self-connections

    console.log(kleur.yellow(`\nConfiguring ${newChain} → ${targetChain} for SummerToken...`))
    try {
      // Create the configuration parameters
      const {
        oAppAddress,
        lzEndpointAddress,
        sendLibraryAddress,
        receiveLibraryAddress,
        sendConfigParams,
        receiveConfigParams,
      } = await createRouteConfiguration(newChain, targetChain, 'summerToken', useBummerConfig)

      console.log(kleur.yellow(`  Attempting direct execution...`))
      const { success, error } = await tryDirectExecution(
        newChain,
        oAppAddress,
        lzEndpointAddress,
        sendLibraryAddress,
        receiveLibraryAddress,
        sendConfigParams,
        receiveConfigParams,
        true, // This is a new chain targeting existing chains
        useBummerConfig,
      )

      if (!success) {
        throw new Error(
          `Failed to configure ${newChain} → ${targetChain}: ${error}\n` +
            `You need to ensure deployer has permissions to configure OApp on ${newChain}.`,
        )
      }

      // Record the successful attempt
      configurationAttempts.push({
        sourceChain: newChain,
        targetChain,
        oAppType: 'summerToken',
        oAppAddress,
        directExecution: true,
        success,
        error,
        lzEndpointAddress,
        sendLibraryAddress,
        receiveLibraryAddress,
        sendConfigParams,
        receiveConfigParams,
      })

      console.log(kleur.green(`  ✓ Successfully configured ${newChain} → ${targetChain}`))
    } catch (error: any) {
      console.log(kleur.red(`  ❌ Error configuring route: ${error.message}`))
      throw new Error(
        `Failed to configure ${newChain} → ${targetChain}: ${error.message}\n` +
          `New chain configurations must be set up directly before transferring ownership. ` +
          `Please address the error above before continuing.`,
      )
    }
  }

  // Phase 2: Configure SummerGovernor routes
  console.log(kleur.cyan('\n--- Phase 2: Configuring SummerGovernor Routes ---'))
  console.log(
    kleur.cyan(
      'SummerGovernor only requires a connection between the new chain and the hub chain.',
    ),
  )

  const hubChain = getHubChain()

  // Configure hub chain to new chain
  console.log(kleur.yellow(`\nConfiguring ${hubChain} → ${newChain} for SummerGovernor...`))
  const {
    oAppAddress,
    lzEndpointAddress,
    sendLibraryAddress,
    receiveLibraryAddress,
    sendConfigParams,
    receiveConfigParams,
  } = await createRouteConfiguration(hubChain, newChain, 'summerGovernor', useBummerConfig)

  try {
    // Create the configuration parameters
    console.log(kleur.yellow(`  Attempting direct execution...`))
    const { success, error } = await tryDirectExecution(
      hubChain,
      oAppAddress,
      lzEndpointAddress,
      sendLibraryAddress,
      receiveLibraryAddress,
      sendConfigParams,
      receiveConfigParams,
      false, // Not a new chain targeting existing
      useBummerConfig,
    )

    if (!success) {
      throw new Error(
        `Failed to configure ${hubChain} → ${newChain}: ${error}\n` +
          `Likely requires governance proposal to be created.`,
      )
    }

    // Record the successful attempt
    configurationAttempts.push({
      sourceChain: hubChain,
      targetChain: newChain,
      oAppType: 'summerGovernor',
      oAppAddress,
      directExecution: true,
      success,
      error,
      lzEndpointAddress,
      sendLibraryAddress,
      receiveLibraryAddress,
      sendConfigParams,
      receiveConfigParams,
    })

    console.log(kleur.green(`  ✓ Successfully configured ${hubChain} → ${newChain}`))
  } catch (error: any) {
    console.log(kleur.red(`  ❌ Error configuring route: ${error.message}`))
    // Still record the attempt
    configurationAttempts.push({
      sourceChain: hubChain,
      targetChain: newChain,
      oAppType: 'summerGovernor',
      oAppAddress,
      directExecution: false,
      success: false,
      error: error.message,
      lzEndpointAddress,
      sendLibraryAddress,
      receiveLibraryAddress,
      sendConfigParams,
      receiveConfigParams,
    })
  }

  // Configure new chain to hub chain
  console.log(kleur.yellow(`\nConfiguring ${newChain} → ${hubChain} for SummerGovernor...`))
  try {
    // Create the configuration parameters
    const {
      oAppAddress,
      lzEndpointAddress,
      sendLibraryAddress,
      receiveLibraryAddress,
      sendConfigParams,
      receiveConfigParams,
    } = await createRouteConfiguration(newChain, hubChain, 'summerGovernor', useBummerConfig)

    console.log(kleur.yellow(`  Attempting direct execution...`))
    const { success, error } = await tryDirectExecution(
      newChain,
      oAppAddress,
      lzEndpointAddress,
      sendLibraryAddress,
      receiveLibraryAddress,
      sendConfigParams,
      receiveConfigParams,
      true, // This is a new chain targeting existing chains
      useBummerConfig,
    )

    if (!success) {
      throw new Error(
        `Direct execution failed for ${newChain} → ${hubChain}: ${error}\n` +
          `New chain configurations must be set up directly before transferring ownership. ` +
          `Please ensure the deployer has proper permissions to configure OApps on ${newChain}.`,
      )
    }

    // Record the successful attempt
    configurationAttempts.push({
      sourceChain: newChain,
      targetChain: hubChain,
      oAppType: 'summerGovernor',
      oAppAddress,
      directExecution: true,
      success: true,
      lzEndpointAddress,
      sendLibraryAddress,
      receiveLibraryAddress,
      sendConfigParams,
      receiveConfigParams,
    })

    console.log(kleur.green(`  ✓ Successfully configured ${newChain} → ${hubChain}`))
  } catch (error: any) {
    console.log(kleur.red(`  ❌ Error configuring route: ${error}`))
    throw new Error(
      `Failed to configure ${newChain} → ${hubChain}: ${error}\n` +
        `New chain configurations must be set up directly before transferring ownership. ` +
        `Please address the error above before continuing.`,
    )
  }

  // Summary of configuration attempts
  console.log(kleur.cyan().bold('\n📊 Configuration Summary:'))

  const successfulConfigs = configurationAttempts.filter((config) => config.success)
  const failedConfigs = configurationAttempts.filter((config) => !config.success)

  console.log(kleur.green(`✓ Successfully configured: ${successfulConfigs.length} routes`))
  console.log(kleur.red(`❌ Failed to configure: ${failedConfigs.length} routes`))

  // If there are failed configurations, offer to create governance proposals

  if (failedConfigs.length > 0) {
    const { createProposals } = await prompts({
      type: 'confirm',
      name: 'createProposals',
      message: 'Do you want to create governance proposals for failed configurations?',
      initial: true,
    })

    if (createProposals) {
      // Optional: Ask for a discourse URL to include with the proposal
      const { discourseURL } = await prompts({
        type: 'text',
        name: 'discourseURL',
        message: 'Enter a discourse URL for the proposals (optional):',
        initial: '',
      })

      // Group failed configurations by chain
      const groupedConfigs = groupConfigurationsByChain(failedConfigs)

      // Create governance proposals - automatically handling hub and cross-chain cases
      await createGovernanceProposals(groupedConfigs, useBummerConfig, newChain, discourseURL)
    }
  }

  console.log(kleur.green().bold('\n✅ LayerZero configuration process complete!'))
}

// Execute the script
if (require.main === module) {
  // Parse command line arguments for --bummer flag
  const args = process.argv.slice(2)
  const useBummerConfig = args.includes('--bummer')

  configureNewChainLayerZero(useBummerConfig).catch((error) => {
    console.error(kleur.red('Error during LayerZero new chain configuration:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { configureNewChainLayerZero, createRouteConfiguration, getDeployedChains }
