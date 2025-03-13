import kleur from 'kleur'
import prompts from 'prompts'
import {
  Address,
  createPublicClient,
  createWalletClient,
  encodeAbiParameters,
  http,
  PublicClient,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { arbitrum, base, mainnet, optimism } from 'viem/chains'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getHubChain } from '../helpers/get-hub-chain'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from '../helpers/tenderly-helpers'
import { createUnifiedLzConfigProposal } from './bridge-governance-helper'

const RPC_URL_MAP = {
  mainnet: process.env.RPC_URL_MAINNET,
  base: process.env.RPC_URL_BASE,
  arbitrum: process.env.RPC_URL_ARBITRUM,
  sonic: process.env.RPC_URL_SONIC,
}

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

// LZ Endpoint interface for setConfig
const lzEndpointAbi = [
  {
    inputs: [
      { name: 'oapp', type: 'address' },
      { name: 'lib', type: 'address' },
      {
        name: 'params',
        type: 'tuple[]',
        components: [
          { name: 'eid', type: 'uint32' },
          { name: 'configType', type: 'uint32' },
          { name: 'config', type: 'bytes' },
        ],
      },
    ],
    name: 'setConfig',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'oapp', type: 'address' }],
    name: 'delegates',
    outputs: [{ name: 'delegate', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

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
 * Check if a route between two chains already exists for an OApp
 */
async function checkExistingRoute(
  sourceChain: string,
  targetChain: string,
  oAppType: 'summerToken' | 'summerGovernor',
  useBummerConfig: boolean,
): Promise<boolean> {
  // This would require looking at the actual contract state or saved configs
  // For now, we'll assume no routes exist and always configure
  // In a production-ready version, this would check the actual chain state
  return false
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
): Promise<{ success: boolean; error?: string }> {
  try {
    throw new Error('Not implemented')
    // Get the source chain configuration to access RPC URLs
    const sourceConfig = getConfigByNetwork(chain, { common: true }, false)

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

    // Use type assertion for the public client to bypass compatibility issues
    const publicClient = createPublicClient({
      chain: chainConfig,
      transport: http(rpcUrl),
    }) as PublicClient

    // Get wallet private key (using environment variable or config)
    const privateKey = process.env.DEPLOYER_PRIVATE_KEY
    if (!privateKey) {
      return {
        success: false,
        error: 'No deployer private key found. Set the DEPLOYER_PRIVATE_KEY environment variable.',
      }
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
    const { isAuthorized, delegate } = await checkLzAuthorizationViem(
      publicClient,
      lzEndpointAddress,
      oAppAddress,
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

    // Set send config
    console.log(kleur.yellow(`  Setting send config on ${chain}...`))
    const sendHash = await walletClient.writeContract({
      address: lzEndpointAddress,
      abi: lzEndpointAbi,
      functionName: 'setConfig',
      args: [oAppAddress, sendLibraryAddress, sendConfigParams],
      chain: chainConfig,
    })

    // Wait for transaction receipt
    console.log(kleur.yellow(`  Waiting for send config transaction to be mined...`))
    await publicClient.waitForTransactionReceipt({ hash: sendHash })
    console.log(kleur.green(`  Send config transaction successful: ${sendHash}`))

    // Set receive config
    console.log(kleur.yellow(`  Setting receive config on ${chain}...`))
    const receiveHash = await walletClient.writeContract({
      address: lzEndpointAddress,
      abi: lzEndpointAbi,
      functionName: 'setConfig',
      args: [oAppAddress, receiveLibraryAddress, receiveConfigParams],
      chain: chainConfig,
    })

    // Wait for transaction receipt
    console.log(kleur.yellow(`  Waiting for receive config transaction to be mined...`))
    await publicClient.waitForTransactionReceipt({ hash: receiveHash })
    console.log(kleur.green(`  Receive config transaction successful: ${receiveHash}`))

    return { success: true }
  } catch (error: any) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }
  }
}

/**
 * Helper function to check LZ authorization using Viem directly
 */
async function checkLzAuthorizationViem(
  publicClient: PublicClient,
  lzEndpointAddress: Address,
  oAppAddress: Address,
): Promise<{ isAuthorized: boolean; delegate: Address }> {
  // Read the delegate from the contract
  const delegate = await publicClient.readContract({
    address: lzEndpointAddress,
    abi: lzEndpointAbi,
    functionName: 'delegates',
    args: [oAppAddress],
  })

  // Get the wallet address
  const walletAddress = privateKeyToAccount(
    process.env.DEPLOYER_PRIVATE_KEY as `0x${string}`,
  ).address

  // Check if wallet is authorized
  const isAuthorized =
    delegate === walletAddress || delegate === '0x0000000000000000000000000000000000000000'

  return { isAuthorized, delegate }
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

  console.log(
    kleur.yellow(
      `\nCreating aggregated proposal with ${hubChainConfigs.length} hub chain configs and ${nonHubChainConfigs.length} cross-chain configs`,
    ),
  )

  try {
    // Create a single proposal containing both hub chain and cross-chain actions
    await createUnifiedLzConfigProposal(
      hubChainConfigs,
      nonHubChainConfigs,
      useBummerConfig,
      newChainName,
      discourseURL,
    )
  } catch (error: any) {
    console.error(kleur.red(`Error creating unified proposal:`))
    console.error(error instanceof Error ? error.message : String(error))
  }
}

/**
 * Configure LayerZero for a new chain with all required routes
 */
async function configureNewChainLayerZero() {
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

  // Ask about using bummer config
  const useBummerConfig = await promptForConfigType()

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
    try {
      // Create the configuration parameters
      const {
        oAppAddress,
        lzEndpointAddress,
        sendLibraryAddress,
        receiveLibraryAddress,
        sendConfigParams,
        receiveConfigParams,
      } = await createRouteConfiguration(sourceChain, newChain, 'summerToken', useBummerConfig)

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
      )

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
        oAppAddress: '0x' as Address, // Placeholder
        directExecution: false,
        success: false,
        error: error.message,
        lzEndpointAddress: '0x' as Address,
        sendLibraryAddress: '0x' as Address,
        receiveLibraryAddress: '0x' as Address,
        sendConfigParams: [],
        receiveConfigParams: [],
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
      )

      // Record the attempt
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

      if (success) {
        console.log(kleur.green(`  ✓ Successfully configured ${newChain} → ${targetChain}`))
      } else {
        console.log(kleur.red(`  ❌ Direct execution failed: ${error}`))
      }
    } catch (error: any) {
      console.log(kleur.red(`  ❌ Error configuring route: ${error.message}`))
      // Still record the attempt
      configurationAttempts.push({
        sourceChain: newChain,
        targetChain,
        oAppType: 'summerToken',
        oAppAddress: '0x' as Address, // Placeholder
        directExecution: false,
        success: false,
        error: error.message,
        lzEndpointAddress: '0x' as Address,
        sendLibraryAddress: '0x' as Address,
        receiveLibraryAddress: '0x' as Address,
        sendConfigParams: [],
        receiveConfigParams: [],
      })
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
  try {
    // Create the configuration parameters
    const {
      oAppAddress,
      lzEndpointAddress,
      sendLibraryAddress,
      receiveLibraryAddress,
      sendConfigParams,
      receiveConfigParams,
    } = await createRouteConfiguration(hubChain, newChain, 'summerGovernor', useBummerConfig)

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
    )

    // Record the attempt
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

    if (success) {
      console.log(kleur.green(`  ✓ Successfully configured ${hubChain} → ${newChain}`))
    } else {
      console.log(kleur.red(`  ❌ Direct execution failed: ${error}`))
    }
  } catch (error: any) {
    console.log(kleur.red(`  ❌ Error configuring route: ${error.message}`))
    // Still record the attempt
    configurationAttempts.push({
      sourceChain: hubChain,
      targetChain: newChain,
      oAppType: 'summerGovernor',
      oAppAddress: '0x' as Address, // Placeholder
      directExecution: false,
      success: false,
      error: error.message,
      lzEndpointAddress: '0x' as Address,
      sendLibraryAddress: '0x' as Address,
      receiveLibraryAddress: '0x' as Address,
      sendConfigParams: [],
      receiveConfigParams: [],
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
    )

    // Record the attempt
    configurationAttempts.push({
      sourceChain: newChain,
      targetChain: hubChain,
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

    if (success) {
      console.log(kleur.green(`  ✓ Successfully configured ${newChain} → ${hubChain}`))
    } else {
      console.log(kleur.red(`  ❌ Direct execution failed: ${error}`))
    }
  } catch (error: any) {
    console.log(kleur.red(`  ❌ Error configuring route: ${error.message}`))
    // Still record the attempt
    configurationAttempts.push({
      sourceChain: newChain,
      targetChain: hubChain,
      oAppType: 'summerGovernor',
      oAppAddress: '0x' as Address, // Placeholder
      directExecution: false,
      success: false,
      error: error.message,
      lzEndpointAddress: '0x' as Address,
      sendLibraryAddress: '0x' as Address,
      receiveLibraryAddress: '0x' as Address,
      sendConfigParams: [],
      receiveConfigParams: [],
    })
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
  configureNewChainLayerZero().catch((error) => {
    console.error(kleur.red('Error during LayerZero new chain configuration:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { configureNewChainLayerZero, createRouteConfiguration, getDeployedChains }
