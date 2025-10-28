import hre from 'hardhat'
import kleur from 'kleur'
import { Address, WalletClient, getAddress } from 'viem'
import layerZeroConfig from '../../../config/adapters/layerzero.json'
import LayerZeroAdapterModule from '../../../ignition/modules/adapters/layerzero'
import {
  getChainIdFromConfig,
  getCrossChainRegistryAddress,
  getLayerZeroEndpoint,
} from '../../lib/config/getters'
import {
  updateIfDifferent,
  waitForTransactionConfirmation,
  writeContractTx,
} from '../../lib/contracts/transactions'
import {
  BRIDGE_ROUTER_REGISTER_ADAPTER_ABI,
  LAYERZERO_SET_MIN_GAS_LIMIT_ABI,
  LAYERZERO_SET_PEER_ABI,
} from './abis'
import { LayerZeroConfig } from './config-types'
import { MESSAGE_TYPES } from './constants'
import { isAdapterRegistered } from './transaction-helpers'
import { BaseConfig, NetworkConfigMap } from './types'
import { getNetworkNameFromChainId, getSupportedChainsFromConfig, getWalletClient } from './utils'

/**
 * Deploy LayerZero adapter using Ignition module
 */
export async function deployLayerZeroAdapter(
  networkConfig: BaseConfig,
  allNetworkConfigs?: NetworkConfigMap,
): Promise<Address> {
  console.log(kleur.blue('Deploying LayerZero adapter using Ignition module'))

  // Get current chain ID
  const chainId = getChainIdFromConfig(networkConfig)

  // Use endpoint from general config
  const endpoint = getLayerZeroEndpoint(networkConfig)

  // Get the crossChainRegistry address from network config
  const crossChainRegistry = getCrossChainRegistryAddress(networkConfig)

  // Build chain mapping from general config
  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)
  const chainIds: number[] = []
  const lzEids: number[] = []

  for (const chain of supportedChains) {
    chainIds.push(chain.chainId)
    lzEids.push(chain.endpointId)
  }

  // Get the deployer address for initialOwner
  const [deployer] = await hre.viem.getWalletClients()
  const signerAddress = deployer.account.address

  // Get the access manager address from network config
  const accessManagerAddress = networkConfig.deployedContracts.gov.protocolAccessManager.address
  if (!accessManagerAddress) {
    throw new Error(`ProtocolAccessManager address not found in config for chain ID ${chainId}`)
  }

  // Deploy using Ignition module
  const deploymentResult = await hre.ignition.deploy(LayerZeroAdapterModule, {
    parameters: {
      LayerZeroAdapterModule: {
        endpoint,
        crossChainRegistry,
        accessManager: accessManagerAddress,
        supportedChains: chainIds,
        lzEids,
        initialOwner: signerAddress,
      },
    },
  })

  const layerZeroAdapterAddress = deploymentResult.layerZeroAdapter.address as Address
  console.log(kleur.green(`LayerZeroAdapter deployed at: ${layerZeroAdapterAddress}`))

  return layerZeroAdapterAddress
}

// Helper function to set minimum gas limits
async function setMinimumGasLimits(
  layerZeroAdapter: Awaited<ReturnType<typeof hre.viem.getContractAt>>,
  walletClient: WalletClient,
  layerZeroAdapterAddress: Address,
  minGasLimits: Record<string, number>,
): Promise<void> {
  for (const [strMsgType, gasLimit] of Object.entries(minGasLimits)) {
    const numMsgType = MESSAGE_TYPES[strMsgType as keyof typeof MESSAGE_TYPES]
    if (numMsgType === undefined) {
      console.error(kleur.red(`Unknown message type: ${strMsgType}, skipping`))
      continue
    }

    try {
      const currentGasLimit = BigInt(String(await layerZeroAdapter.read.minGasLimits([numMsgType])))
      const configuredGasLimit = BigInt(gasLimit)

      await updateIfDifferent(
        layerZeroAdapter,
        walletClient,
        'minGasLimits',
        currentGasLimit,
        configuredGasLimit,
        () =>
          writeContractTx(
            walletClient,
            layerZeroAdapterAddress,
            LAYERZERO_SET_MIN_GAS_LIMIT_ABI,
            'setMinGasLimit',
            [numMsgType, configuredGasLimit],
          ),
        `Setting minimum gas limit for message type ${strMsgType} (${numMsgType}) to ${gasLimit}`,
      )
    } catch (error) {
      console.error(
        kleur.red(`Error setting minimum gas limit for message type ${strMsgType}:`),
        error,
      )
    }
  }
}

// Helper function to register adapter with bridge router
async function registerWithBridgeRouter(
  walletClient: WalletClient,
  bridgeRouterAddress: Address,
  layerZeroAdapterAddress: Address,
): Promise<void> {
  try {
    const alreadyRegistered = await isAdapterRegistered(
      bridgeRouterAddress,
      layerZeroAdapterAddress,
    )

    if (!alreadyRegistered) {
      const hash = await writeContractTx(
        walletClient,
        bridgeRouterAddress,
        BRIDGE_ROUTER_REGISTER_ADAPTER_ABI,
        'registerAdapter',
        [getAddress(layerZeroAdapterAddress)],
      )
      console.log(kleur.green(`LayerZero adapter registered with bridge router, tx: ${hash}`))
    } else {
      console.log(
        kleur.yellow(
          `LayerZero adapter already registered with bridge router, skipping registration`,
        ),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error registering adapter with bridge router:'), error)
    throw error
  }
}

// Main configuration function
export async function configureLayerZeroAdapter(
  layerZeroAdapterAddress: Address,
  bridgeRouterAddress: Address,
  networkConfig: BaseConfig,
): Promise<void> {
  console.log(kleur.blue('Configuring LayerZero adapter'))

  const chainId = Number(networkConfig.common.chainId)
  const chainConfig = (layerZeroConfig as LayerZeroConfig).chainConfig[chainId.toString()]

  if (!chainConfig) {
    console.log(kleur.yellow(`No LayerZero configuration found for chain ${chainId}, skipping`))
    return
  }

  const layerZeroAdapter = await hre.viem.getContractAt(
    'LayerZeroAdapter' as string,
    getAddress(layerZeroAdapterAddress as `0x${string}`),
  )

  const walletClient = await getWalletClient()
  const publicClient = await hre.viem.getPublicClient()

  // Step 1: Set minimum gas limits
  if (chainConfig.minGasLimits) {
    await setMinimumGasLimits(
      layerZeroAdapter,
      walletClient,
      layerZeroAdapterAddress,
      chainConfig.minGasLimits,
    )
  }

  // Step 5: Register adapter with bridge router
  await registerWithBridgeRouter(walletClient, bridgeRouterAddress, layerZeroAdapterAddress)
}

/**
 * Update LayerZero adapter peers after all adapters are deployed across chains
 */
export async function updateLayerZeroAdapterPeers(
  layerZeroAdapterAddress: Address,
  allNetworkConfigs: NetworkConfigMap,
): Promise<void> {
  console.log(kleur.blue('Configuring LayerZero adapter peers'))

  const layerZeroAdapter = await hre.viem.getContractAt(
    'LayerZeroAdapter' as string,
    getAddress(layerZeroAdapterAddress as `0x${string}`),
  )

  // Get wallet client for transactions using proper setup
  const walletClient = await getWalletClient()

  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  // Filter to only include chains that have LayerZero adapters deployed
  const availableChains = supportedChains.filter((chainInfo) => {
    const targetNetworkName = getNetworkNameFromChainId(chainInfo.chainId)
    const targetNetworkConfig = allNetworkConfigs[targetNetworkName]
    return targetNetworkConfig?.deployedContracts?.bridge?.adapters?.layerZero?.address
  })

  if (availableChains.length === 0) {
    console.log(
      kleur.yellow('No other chains with LayerZero adapters found, skipping peer configuration'),
    )
    return
  }

  console.log(
    kleur.blue(`Found ${availableChains.length} chains with LayerZero adapters for peering`),
  )

  for (const chainInfo of availableChains) {
    try {
      const targetNetworkName = getNetworkNameFromChainId(chainInfo.chainId)
      const targetNetworkConfig = allNetworkConfigs[targetNetworkName]
      const targetAdapterAddress =
        targetNetworkConfig?.deployedContracts?.bridge?.adapters?.layerZero?.address

      if (targetAdapterAddress) {
        // Check if peer is already set
        let currentPeer: string
        try {
          const result = await layerZeroAdapter.read.peers([chainInfo.endpointId])
          currentPeer = result as string
        } catch (error) {
          // If the call fails, peer might not be set yet
          currentPeer = '0x0000000000000000000000000000000000000000000000000000000000000000'
        }

        // Format peer address as bytes32 (padded with zeros)
        const peerAddressBytes32 =
          `0x000000000000000000000000${targetAdapterAddress.slice(2)}` as `0x${string}`

        if (currentPeer.toLowerCase() !== peerAddressBytes32.toLowerCase()) {
          console.log(
            `Setting peer for LayerZero EID ${chainInfo.endpointId} to adapter ${targetAdapterAddress}`,
          )

          // Use wallet client directly instead of .write
          const hash = await writeContractTx(
            walletClient,
            layerZeroAdapterAddress,
            LAYERZERO_SET_PEER_ABI,
            'setPeer',
            [chainInfo.endpointId, peerAddressBytes32 as `0x${string}`],
          )

          console.log(kleur.green(`Peer set for EID ${chainInfo.endpointId}, tx: ${hash}`))

          await waitForTransactionConfirmation(hash)
        } else {
          console.log(
            kleur.yellow(`Peer for EID ${chainInfo.endpointId} already set correctly, skipping`),
          )
        }
      } else {
        console.log(
          kleur.yellow(
            `No LayerZero adapter address found for chain ${chainInfo.chainId}, skipping peer setup`,
          ),
        )
      }
    } catch (error) {
      console.error(kleur.red(`Error setting peer for EID ${chainInfo.endpointId}:`), error)
    }
  }
}

/**
 * Configure LayerZero adapter peers with support for bummer config
 */
export async function configureLayerZeroAdapterPeersWithConfig(
  networkName: string,
  useBummerConfig: boolean = false,
  supportedNetworks: string[] = ['mainnet', 'base', 'arbitrum', 'sonic'],
): Promise<void> {
  console.log(kleur.cyan().bold(`Configuring LayerZero adapter peers on ${networkName}...`))

  // Get current network config
  const { getConfigByNetwork } = await import('../../lib/config/handler')

  const currentNetworkConfig = getConfigByNetwork(
    networkName,
    {
      common: true,
      bridge: false,
      gov: false,
      core: false,
    },
    useBummerConfig,
  )

  // Check if bridge configuration exists
  if (!currentNetworkConfig.deployedContracts.bridge) {
    throw new Error(
      `Bridge deployment configuration not found for network ${networkName}. Please deploy bridge contracts first.`,
    )
  }

  const layerZeroAdapterAddress =
    currentNetworkConfig.deployedContracts.bridge?.adapters?.layerZero?.address

  if (!layerZeroAdapterAddress) {
    throw new Error(
      `LayerZero adapter not found in config for network ${networkName}. Please deploy LayerZero adapter first.`,
    )
  }

  // Load all network configurations
  const allNetworkConfigs: NetworkConfigMap = {}

  for (const network of supportedNetworks) {
    try {
      const config = getConfigByNetwork(
        network,
        {
          common: true,
          bridge: false,
          gov: false,
          core: false,
        },
        useBummerConfig,
      )

      // Check if this network has a LayerZero adapter deployed
      if (config.deployedContracts.bridge?.adapters?.layerZero?.address) {
        allNetworkConfigs[network] = config
        console.log(kleur.green(`✓ Loaded config for ${network}`))
      } else {
        console.log(kleur.yellow(`⚠ ${network} doesn't have LayerZero adapter deployed, skipping`))
      }
    } catch (error) {
      console.log(
        kleur.yellow(`⚠ Could not load config for ${network}: ${(error as Error).message}`),
      )
    }
  }

  // Configure peers
  await updateLayerZeroAdapterPeers(layerZeroAdapterAddress as Address, allNetworkConfigs)
}
