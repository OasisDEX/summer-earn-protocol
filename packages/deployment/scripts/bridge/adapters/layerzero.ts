import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import layerZeroConfig from '../../../config/adapters/layerzero.json'
import LayerZeroAdapterModule from '../../../ignition/modules/adapters/layerzero'
import {
  extractBridgeRouterAddress,
  getNetworkNameFromChainId,
  getSupportedChainsFromConfig,
  getWalletClient,
} from './utils'

/**
 * Deploy LayerZero adapter using Ignition module
 */
export async function deployLayerZeroAdapter(
  crossChainRegistry: Address,
  networkConfig: any,
  allNetworkConfigs?: Record<string, any>,
): Promise<Address> {
  console.log(kleur.blue('Deploying LayerZero adapter using Ignition module'))

  // Get current chain ID
  const chainId = Number(networkConfig.common.chainId)

  // Use endpoint from general config
  const endpoint = networkConfig.common.layerZero.lzEndpoint
  if (!endpoint) {
    throw new Error(`LayerZero endpoint not configured for chain ID ${chainId}`)
  }

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

// Helper function to activate read channel
async function activateReadChannel(
  layerZeroAdapter: any,
  walletClient: any,
  layerZeroAdapterAddress: Address,
  readChannelId: number,
): Promise<void> {
  try {
    const currentReadChannelId = BigInt(String(await layerZeroAdapter.read.readChannelId()))

    if (currentReadChannelId !== BigInt(readChannelId)) {
      console.log(`Activating read channel with ID ${readChannelId}`)
      const hash = await walletClient.writeContract({
        address: getAddress(layerZeroAdapterAddress as `0x${string}`),
        abi: [
          {
            inputs: [{ internalType: 'uint32', name: 'channelId', type: 'uint32' }],
            name: 'activateReadChannel',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'activateReadChannel',
        args: [readChannelId],
      })
      console.log(kleur.green(`Read channel activated successfully, tx: ${hash}`))

      const verifyReadChannelId = BigInt(String(await layerZeroAdapter.read.readChannelId()))
      console.log(kleur.blue(`Read channel ID verified: ${verifyReadChannelId}`))
    } else {
      console.log(kleur.yellow(`Read channel ${readChannelId} already active, skipping`))
    }
  } catch (error) {
    console.error(kleur.red('Error activating read channel:'), error)
    throw error
  }
}

// Helper function to configure ReadLib1002 libraries
async function configureReadLib1002(
  layerZeroAdapter: any,
  walletClient: any,
  publicClient: any,
  layerZeroAdapterAddress: Address,
  endpointAddress: Address,
  readChannelId: number,
  readLib1002Address: Address,
): Promise<void> {
  try {
    const currentReadChannelId = BigInt(String(await layerZeroAdapter.read.readChannelId()))
    if (currentReadChannelId === BigInt(0)) {
      throw new Error('Read channel must be activated before configuring libraries')
    }

    let needsConfiguration = false

    // Check send library
    try {
      const currentSendLib = await publicClient.readContract({
        address: endpointAddress,
        abi: [
          {
            inputs: [
              { internalType: 'address', name: 'oApp', type: 'address' },
              { internalType: 'uint32', name: 'eid', type: 'uint32' },
            ],
            name: 'getSendLibrary',
            outputs: [{ internalType: 'address', name: '', type: 'address' }],
            stateMutability: 'view',
            type: 'function',
          },
        ] as const,
        functionName: 'getSendLibrary',
        args: [getAddress(layerZeroAdapterAddress), readChannelId],
      })

      if (currentSendLib.toLowerCase() !== readLib1002Address.toLowerCase()) {
        needsConfiguration = true
        console.log(`Send library needs update: ${currentSendLib} -> ${readLib1002Address}`)
      }
    } catch (error) {
      needsConfiguration = true
      console.log('Could not check current send library, assuming needs configuration')
    }

    // Check receive library if needed
    if (!needsConfiguration) {
      try {
        const currentReceiveLib = await publicClient.readContract({
          address: endpointAddress,
          abi: [
            {
              inputs: [
                { internalType: 'address', name: 'oApp', type: 'address' },
                { internalType: 'uint32', name: 'eid', type: 'uint32' },
              ],
              name: 'getReceiveLibrary',
              outputs: [{ internalType: 'address', name: '', type: 'address' }],
              stateMutability: 'view',
              type: 'function',
            },
          ] as const,
          functionName: 'getReceiveLibrary',
          args: [getAddress(layerZeroAdapterAddress), readChannelId],
        })

        if (currentReceiveLib.toLowerCase() !== readLib1002Address.toLowerCase()) {
          needsConfiguration = true
          console.log(`Receive library needs update: ${currentReceiveLib} -> ${readLib1002Address}`)
        }
      } catch (error) {
        needsConfiguration = true
        console.log('Could not check current receive library, assuming needs configuration')
      }
    }

    if (needsConfiguration) {
      console.log(`Configuring ReadLib1002 libraries with address ${readLib1002Address}`)
      const hash = await walletClient.writeContract({
        address: getAddress(layerZeroAdapterAddress),
        abi: [
          {
            inputs: [{ internalType: 'address', name: 'readLib1002Address', type: 'address' }],
            name: 'configureReadLibraries',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'configureReadLibraries',
        args: [readLib1002Address],
      })
      console.log(kleur.green(`ReadLib1002 libraries configured successfully, tx: ${hash}`))
    } else {
      console.log(kleur.yellow(`ReadLib1002 libraries already configured correctly, skipping`))
    }
  } catch (error) {
    console.error(kleur.red('Error configuring ReadLib1002 libraries:'), error)
    throw error
  }
}

// Helper function to configure DVNs and executor
async function configureDVNsAndExecutor(
  layerZeroAdapter: any,
  walletClient: any,
  publicClient: any,
  layerZeroAdapterAddress: Address,
  readLib1002Address: Address,
  readDVNs: Address[],
  confirmations: number,
  executor: Address,
): Promise<void> {
  try {
    const currentReadChannelId = BigInt(String(await layerZeroAdapter.read.readChannelId()))
    if (currentReadChannelId === BigInt(0)) {
      throw new Error('Read channel must be activated before configuring DVNs')
    }

    console.log(`Configuring read DVNs and executor for read operations`)
    console.log(`- ReadLib1002: ${readLib1002Address}`)
    console.log(`- DVNs: ${readDVNs.join(', ')}`)
    console.log(`- Executor: ${executor}`)
    console.log(`- Confirmations: ${confirmations}`)

    const hash = await walletClient.writeContract({
      address: getAddress(layerZeroAdapterAddress),
      abi: [
        {
          inputs: [
            { internalType: 'address', name: 'readLib1002Address', type: 'address' },
            { internalType: 'address[]', name: 'readDVNs', type: 'address[]' },
            { internalType: 'uint64', name: 'confirmations', type: 'uint64' },
            { internalType: 'address', name: 'executor', type: 'address' },
          ],
          name: 'configureReadDVNs',
          outputs: [],
          stateMutability: 'nonpayable',
          type: 'function',
        },
      ] as const,
      functionName: 'configureReadDVNs',
      args: [readLib1002Address, readDVNs, confirmations, executor],
    })
    console.log(kleur.green(`Read DVNs and executor configured successfully, tx: ${hash}`))

    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green(`Read DVNs configuration transaction confirmed`))
  } catch (error) {
    console.error(kleur.red('Error configuring read DVNs and executor:'), error)
    throw error
  }
}

// Helper function to set minimum gas limits
async function setMinimumGasLimits(
  layerZeroAdapter: any,
  walletClient: any,
  layerZeroAdapterAddress: Address,
  minGasLimits: Record<string, number>,
): Promise<void> {
  const messageTypeMap: Record<string, number> = {
    stateRead: 2,
    generalMessage: 3,
  }

  for (const [strMsgType, gasLimit] of Object.entries(minGasLimits)) {
    const numMsgType = messageTypeMap[strMsgType]
    if (numMsgType === undefined) {
      console.error(kleur.red(`Unknown message type: ${strMsgType}, skipping`))
      continue
    }

    try {
      const currentGasLimit = BigInt(String(await layerZeroAdapter.read.minGasLimits([numMsgType])))
      const configuredGasLimit = BigInt(gasLimit)

      if (currentGasLimit !== configuredGasLimit) {
        console.log(
          `Setting minimum gas limit for message type ${strMsgType} (${numMsgType}) to ${gasLimit}`,
        )
        const hash = await walletClient.writeContract({
          address: getAddress(layerZeroAdapterAddress),
          abi: [
            {
              inputs: [
                { internalType: 'uint16', name: 'msgType', type: 'uint16' },
                { internalType: 'uint128', name: 'gasLimit', type: 'uint128' },
              ],
              name: 'setMinGasLimit',
              outputs: [],
              stateMutability: 'nonpayable',
              type: 'function',
            },
          ] as const,
          functionName: 'setMinGasLimit',
          args: [numMsgType, configuredGasLimit],
        })
        console.log(
          kleur.green(
            `Minimum gas limit for message type ${strMsgType} updated successfully, tx: ${hash}`,
          ),
        )
      } else {
        console.log(
          kleur.yellow(
            `Minimum gas limit for message type ${strMsgType} already set to ${currentGasLimit}, skipping`,
          ),
        )
      }
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
  walletClient: any,
  bridgeRouterAddress: Address,
  layerZeroAdapterAddress: Address,
): Promise<void> {
  try {
    const actualAddress = extractBridgeRouterAddress(bridgeRouterAddress)

    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as any,
      getAddress(actualAddress as `0x${string}`),
    )

    const alreadyRegistered = Boolean(
      await bridgeRouter.read.isValidAdapter([getAddress(layerZeroAdapterAddress)]),
    )

    if (!alreadyRegistered) {
      const hash = await walletClient.writeContract({
        address: getAddress(actualAddress),
        abi: [
          {
            inputs: [{ internalType: 'address', name: 'adapter', type: 'address' }],
            name: 'registerAdapter',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'registerAdapter',
        args: [getAddress(layerZeroAdapterAddress)],
      })
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
  networkConfig: any,
): Promise<void> {
  console.log(kleur.blue('Configuring LayerZero adapter'))

  const chainId = Number(networkConfig.common.chainId)
  const chainConfig = (layerZeroConfig.chainConfig as any)[chainId.toString()]

  if (!chainConfig) {
    console.log(kleur.yellow(`No LayerZero configuration found for chain ${chainId}, skipping`))
    return
  }

  const layerZeroAdapter = await hre.viem.getContractAt(
    'LayerZeroAdapter' as any,
    getAddress(layerZeroAdapterAddress as `0x${string}`),
  )

  const walletClient = await getWalletClient()
  const publicClient = await hre.viem.getPublicClient()

  // Step 1: Activate read channel
  if (chainConfig.readChannelId) {
    await activateReadChannel(
      layerZeroAdapter,
      walletClient,
      layerZeroAdapterAddress,
      chainConfig.readChannelId,
    )
  } else {
    console.log(kleur.yellow('No read channel ID configured, skipping read channel activation'))
  }

  // Step 2: Configure ReadLib1002 libraries
  if (chainConfig.readLib1002 && chainConfig.readChannelId) {
    await configureReadLib1002(
      layerZeroAdapter,
      walletClient,
      publicClient,
      layerZeroAdapterAddress,
      networkConfig.common.layerZero.lzEndpoint,
      chainConfig.readChannelId,
      chainConfig.readLib1002,
    )
  } else {
    if (!chainConfig.readLib1002)
      console.log(kleur.yellow('No ReadLib1002 address configured, skipping library configuration'))
    if (!chainConfig.readChannelId)
      console.log(kleur.yellow('No read channel ID configured, skipping library configuration'))
  }

  // Step 3: Configure DVNs and executor
  if (
    chainConfig.readLib1002 &&
    chainConfig.readDVNs &&
    chainConfig.executor &&
    chainConfig.confirmations
  ) {
    await configureDVNsAndExecutor(
      layerZeroAdapter,
      walletClient,
      publicClient,
      layerZeroAdapterAddress,
      chainConfig.readLib1002,
      chainConfig.readDVNs,
      chainConfig.confirmations,
      chainConfig.executor,
    )
  } else {
    console.log(kleur.yellow('Missing read configuration parameters, skipping DVN configuration'))
    if (!chainConfig.readLib1002) console.log(kleur.yellow('  - Missing readLib1002'))
    if (!chainConfig.readDVNs) console.log(kleur.yellow('  - Missing readDVNs'))
    if (!chainConfig.executor) console.log(kleur.yellow('  - Missing executor'))
    if (!chainConfig.confirmations) console.log(kleur.yellow('  - Missing confirmations'))
  }

  // Step 4: Set minimum gas limits
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
  allNetworkConfigs: Record<string, any>,
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
          const hash = await walletClient.writeContract({
            address: getAddress(layerZeroAdapterAddress as `0x${string}`),
            abi: [
              {
                inputs: [
                  { internalType: 'uint32', name: '_eid', type: 'uint32' },
                  { internalType: 'bytes32', name: '_peer', type: 'bytes32' },
                ],
                name: 'setPeer',
                outputs: [],
                stateMutability: 'nonpayable',
                type: 'function',
              },
            ] as const,
            functionName: 'setPeer',
            args: [chainInfo.endpointId, peerAddressBytes32],
          })

          console.log(kleur.green(`Peer set for EID ${chainInfo.endpointId}, tx: ${hash}`))

          // Wait for transaction confirmation
          const publicClient = await hre.viem.getPublicClient()
          await publicClient.waitForTransactionReceipt({ hash })
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
  const { getConfigByNetwork } = await import('../../helpers/config-handler')

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
  const allNetworkConfigs: Record<string, any> = {}

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
