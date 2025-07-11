import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import stargateConfig from '../../../config/adapters/stargate.json'
import StargateAdapterModule from '../../../ignition/modules/adapters/stargate'
import { getNetworkNameFromChainId, getSupportedChainsFromConfig, getWalletClient } from './utils'

// Define a type for the bridge router address parameter
type BridgeRouterAddressParam = Address | { bridgeRouterAddress: Address }

// Simple ABI for IStargatePool interface validation
const IStargatePoolABI = [
  {
    inputs: [],
    name: 'token',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

// Simple ABI for IStargate OFT interface validation
const IStargateOFTABI = [
  {
    inputs: [],
    name: 'stargateType',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

// Additional ABI for other potential Stargate contract types
const IStargateCommonABI = [
  {
    inputs: [],
    name: 'localDecimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'sharedDecimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

// Cache for validated contracts
const validatedContracts = new Set<string>()

/**
 * Deploy Stargate adapter using Ignition module
 */
export async function deployStargateAdapter(
  crossChainRegistry: Address,
  accessManager: Address,
  networkConfig: any,
): Promise<Address> {
  console.log(kleur.blue('Deploying Stargate V2 adapter using Ignition module'))

  // Get LayerZero endpoint from network config
  const lzEndpoint = networkConfig.common.layerZero.lzEndpoint
  if (!lzEndpoint) {
    throw new Error(
      `LayerZero endpoint not configured for chain ID ${networkConfig.common.chainId}`,
    )
  }

  // Get HarborCommand address from network config
  const harborCommand = networkConfig.deployedContracts.core.harborCommand.address
  if (!harborCommand) {
    throw new Error(
      `HarborCommand address not found in config for chain ID ${networkConfig.common.chainId}`,
    )
  }

  // Deploy using Ignition module - all 4 constructor parameters needed
  const deploymentResult = await hre.ignition.deploy(StargateAdapterModule, {
    parameters: {
      StargateAdapterModule: {
        crossChainRegistry,
        accessManager,
        lzEndpoint,
        harborCommand,
      },
    },
  })

  const stargateAdapterAddress = deploymentResult.stargateAdapter.address as Address
  console.log(kleur.green(`StargateAdapter V2 deployed at: ${stargateAdapterAddress}`))

  return stargateAdapterAddress
}

/**
 * Configure supported chains and assets for Stargate V2 adapter
 */
export async function configureStargateAdapter(
  stargateAdapterAddress: Address,
  bridgeRouterAddress: BridgeRouterAddressParam,
  networkConfig: any,
  allNetworkConfigs?: Record<string, any>,
): Promise<void> {
  console.log(kleur.blue('Configuring Stargate V2 adapter'))

  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    getAddress(stargateAdapterAddress as `0x${string}`),
  )

  // Get wallet client for transactions using proper setup
  const walletClient = await getWalletClient()

  const currentChainId = Number(networkConfig.common.chainId)
  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  // Debug logging
  console.log(
    'allNetworkConfigs keys:',
    allNetworkConfigs ? Object.keys(allNetworkConfigs) : 'undefined',
  )
  console.log('supportedChains:', supportedChains)

  // Add supported chains (using general config)
  let chainsAdded = 0
  for (const chainInfo of supportedChains) {
    if (chainInfo.chainId === currentChainId) {
      continue // Skip current chain
    }

    try {
      // Check if chain is already supported
      let existingEndpointId = 0
      try {
        existingEndpointId = Number(
          await stargateAdapter.read.chainToEndpointId([chainInfo.chainId]),
        )
      } catch (error) {
        // If the call fails, it means the chain is not supported yet (which is expected)
        console.log(`Chain ${chainInfo.chainId} not yet supported, will add it`)
        existingEndpointId = 0
      }

      if (existingEndpointId === 0) {
        console.log(
          `Adding supported chain ${chainInfo.chainId} with LayerZero endpoint ID ${chainInfo.endpointId}`,
        )

        // Determine adapter address for this chain
        let adapterAddress: Address

        if (chainInfo.chainId === currentChainId) {
          // For current chain, use the current adapter address
          adapterAddress = stargateAdapterAddress
        } else {
          // For other chains, check if we have the adapter address in config
          const targetNetworkName = getNetworkNameFromChainId(chainInfo.chainId)
          const targetNetworkConfig = allNetworkConfigs?.[targetNetworkName]
          const existingAdapterAddress =
            targetNetworkConfig?.deployedContracts?.bridge?.adapters?.stargate?.address

          if (
            existingAdapterAddress &&
            existingAdapterAddress !== '0x0000000000000000000000000000000000000000'
          ) {
            adapterAddress = existingAdapterAddress as Address
            console.log(
              `Using existing adapter address for chain ${chainInfo.chainId}: ${adapterAddress}`,
            )
          } else {
            // Skip this chain for now - will be added when that chain's adapter is deployed
            console.log(`No adapter address found for chain ${chainInfo.chainId}, skipping for now`)
            continue
          }
        }

        // Use wallet client directly instead of .write
        const hash = await walletClient.writeContract({
          address: getAddress(stargateAdapterAddress as `0x${string}`),
          abi: [
            {
              inputs: [
                { internalType: 'uint16', name: 'chainId', type: 'uint16' },
                { internalType: 'uint32', name: 'endpointId', type: 'uint32' },
                { internalType: 'address', name: 'adapterAddress', type: 'address' },
              ],
              name: 'addSupportedChain',
              outputs: [],
              stateMutability: 'nonpayable',
              type: 'function',
            },
          ] as const,
          functionName: 'addSupportedChain',
          args: [chainInfo.chainId, chainInfo.endpointId, adapterAddress],
        })
        console.log(kleur.green(`Chain ${chainInfo.chainId} added successfully, tx: ${hash}`))

        // Wait for transaction confirmation
        const publicClient = await hre.viem.getPublicClient()
        await publicClient.waitForTransactionReceipt({ hash })
        console.log(kleur.green(`Chain ${chainInfo.chainId} transaction confirmed`))
        chainsAdded++
      } else {
        console.log(kleur.yellow(`Chain ${chainInfo.chainId} already supported, skipping`))
      }
    } catch (error) {
      console.error(kleur.red(`Error adding chain ${chainInfo.chainId}:`), error)
    }
  }

  console.log(kleur.green(`Added ${chainsAdded} new supported chains`))

  // Only add delay if we actually added chains
  if (chainsAdded > 0) {
    console.log(kleur.blue(`Added ${chainsAdded} new chains, waiting for settlement...`))
    await new Promise((resolve) => setTimeout(resolve, 2000))
  }

  // Get Stargate contracts for current chain
  const currentChainContracts = (stargateConfig.contracts as any)[currentChainId.toString()]
  if (!currentChainContracts) {
    console.log(
      kleur.yellow(
        `No Stargate V2 contracts found for current chain ${currentChainId}, skipping asset configuration`,
      ),
    )
    return
  }

  // Configure supported assets
  let assetsConfigured = 0
  for (const [assetSymbol, stargateContract] of Object.entries(currentChainContracts)) {
    // Get token address from general config
    const localAssetAddress = networkConfig.tokens[assetSymbol === 'eth' ? 'weth' : assetSymbol]

    if (localAssetAddress && stargateContract) {
      // Ensure addresses are properly checksummed
      const checksummedLocalAddress = getAddress(localAssetAddress)
      const checksummedStargateContract = getAddress(stargateContract as string)

      console.log(
        `Configuring asset ${assetSymbol} (${checksummedLocalAddress}) with Stargate contract ${checksummedStargateContract}`,
      )

      // Validate Stargate contract before adding asset (with caching)
      const contractKey = `${currentChainId}-${checksummedStargateContract}`
      if (!validatedContracts.has(contractKey)) {
        try {
          const isValid = await validateStargateContract(checksummedStargateContract)
          if (!isValid) {
            console.error(
              kleur.red(
                `Invalid Stargate contract ${checksummedStargateContract}: Failed validation`,
              ),
            )
            continue // Skip this asset
          }
          validatedContracts.add(contractKey)
          console.log(kleur.green(`✓ Stargate contract ${checksummedStargateContract} validated`))
        } catch (error) {
          console.error(
            kleur.red(`Error validating Stargate contract ${checksummedStargateContract}:`),
            error,
          )
          continue // Skip this asset
        }
      } else {
        console.log(
          kleur.blue(`✓ Stargate contract ${checksummedStargateContract} already validated`),
        )
      }

      // Check current chain asset mapping
      try {
        const currentStargateContract = String(
          await stargateAdapter.read.assetToStargateContract([checksummedLocalAddress]),
        )

        if (
          currentStargateContract === '0x0000000000000000000000000000000000000000' ||
          currentStargateContract.toLowerCase() !== checksummedStargateContract.toLowerCase()
        ) {
          console.log(
            `Adding supported asset ${checksummedLocalAddress} for current chain ${currentChainId}`,
          )
          // Use wallet client directly instead of .write
          const hash = await walletClient.writeContract({
            address: getAddress(stargateAdapterAddress as `0x${string}`),
            abi: [
              {
                inputs: [
                  { internalType: 'address', name: 'asset', type: 'address' },
                  { internalType: 'address', name: 'stargateContract', type: 'address' },
                ],
                name: 'addSupportedAsset',
                outputs: [],
                stateMutability: 'nonpayable',
                type: 'function',
              },
            ] as const,
            functionName: 'addSupportedAsset',
            args: [checksummedLocalAddress, checksummedStargateContract],
          })
          console.log(
            kleur.green(
              `Asset mapping for ${checksummedLocalAddress} on current chain added, tx: ${hash}`,
            ),
          )
          assetsConfigured++
        } else {
          console.log(kleur.yellow(`Asset mapping for current chain already correct, skipping`))
        }
      } catch (error) {
        console.error(kleur.red(`Error configuring asset mapping for current chain:`), error)
      }
    } else {
      console.log(
        kleur.yellow(
          `Asset ${assetSymbol} not available on current chain ${currentChainId} (address: ${localAssetAddress}), skipping`,
        ),
      )
    }
  }

  console.log(kleur.blue(`Configured ${assetsConfigured} asset mappings`))

  // Set compose gas limit from Stargate config (with check)
  try {
    const currentGasLimit = BigInt(String(await stargateAdapter.read.composeGasLimit()))
    // Use composeGasLimit from config or default to 700000 (matching contract default)
    const configuredGasLimit = BigInt(stargateConfig.composeGasLimit || 700000)

    if (currentGasLimit !== configuredGasLimit) {
      // Use wallet client directly instead of .write
      const hash = await walletClient.writeContract({
        address: getAddress(stargateAdapterAddress as `0x${string}`),
        abi: [
          {
            inputs: [{ internalType: 'uint256', name: '_composeGasLimit', type: 'uint256' }],
            name: 'setComposeGasLimit',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'setComposeGasLimit',
        args: [configuredGasLimit],
      })
      console.log(kleur.green(`Compose gas limit updated to ${configuredGasLimit}, tx: ${hash}`))
    } else {
      console.log(kleur.yellow(`Compose gas limit already set to ${currentGasLimit}, skipping`))
    }
  } catch (error) {
    console.error(kleur.red('Error setting compose gas limit:'), error)
  }

  // Set default transport mode from Stargate config (with check)
  try {
    const defaultUseTaxi = stargateConfig.defaultUseTaxi || false
    const currentUseTaxi = Boolean(await stargateAdapter.read.defaultUseTaxi())

    if (currentUseTaxi !== defaultUseTaxi) {
      // Use wallet client directly instead of .write
      const hash = await walletClient.writeContract({
        address: getAddress(stargateAdapterAddress as `0x${string}`),
        abi: [
          {
            inputs: [{ internalType: 'bool', name: 'useTaxi', type: 'bool' }],
            name: 'setDefaultTransportMode',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'setDefaultTransportMode',
        args: [defaultUseTaxi],
      })
      console.log(
        kleur.green(
          `Default transport mode updated to ${defaultUseTaxi ? 'taxi' : 'bus'}, tx: ${hash}`,
        ),
      )
    } else {
      console.log(
        kleur.yellow(
          `Default transport mode already set to ${defaultUseTaxi ? 'taxi' : 'bus'}, skipping`,
        ),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error setting default transport mode:'), error)
  }

  // Register adapter with bridge router (existing check is good)
  try {
    const actualAddress = extractBridgeRouterAddress(bridgeRouterAddress)

    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as string,
      getAddress(actualAddress),
    )

    const alreadyRegistered = Boolean(
      await bridgeRouter.read.isValidAdapter([getAddress(stargateAdapterAddress as `0x${string}`)]),
    )

    if (!alreadyRegistered) {
      // Use wallet client directly instead of .write
      const hash = await walletClient.writeContract({
        address: getAddress(actualAddress as `0x${string}`),
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
        args: [getAddress(stargateAdapterAddress as `0x${string}`)],
      })
      console.log(kleur.green(`Stargate V2 adapter registered with bridge router, tx: ${hash}`))
    } else {
      console.log(
        kleur.yellow(
          `Stargate V2 adapter already registered with bridge router, skipping registration`,
        ),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error registering adapter with bridge router:'), error)
  }
}

/**
 * Update adapter addresses for cross-chain support after all adapters are deployed
 */
export async function updateStargateAdapterAddresses(
  stargateAdapterAddress: Address,
  allNetworkConfigs: Record<string, any>,
): Promise<void> {
  console.log(kleur.blue('Updating Stargate adapter cross-chain addresses'))

  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    getAddress(stargateAdapterAddress as `0x${string}`),
  )

  // Get wallet client for transactions using proper setup
  const walletClient = await getWalletClient()

  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  for (const chainInfo of supportedChains) {
    try {
      const targetNetworkName = getNetworkNameFromChainId(chainInfo.chainId)
      const targetNetworkConfig = allNetworkConfigs[targetNetworkName]
      const targetAdapterAddress =
        targetNetworkConfig?.deployedContracts?.bridge?.adapters?.stargate?.address

      if (targetAdapterAddress) {
        // Check if the current adapter address is correct
        const currentAdapterAddress = (await stargateAdapter.read.chainToAdapter([
          chainInfo.chainId,
        ])) as string

        if (currentAdapterAddress.toLowerCase() !== targetAdapterAddress.toLowerCase()) {
          console.log(
            `Updating adapter address for chain ${chainInfo.chainId} from ${currentAdapterAddress} to ${targetAdapterAddress}`,
          )

          // Use wallet client directly instead of .write
          const hash = await walletClient.writeContract({
            address: getAddress(stargateAdapterAddress as `0x${string}`),
            abi: [
              {
                inputs: [
                  { internalType: 'uint16', name: 'chainId', type: 'uint16' },
                  { internalType: 'address', name: 'adapterAddress', type: 'address' },
                ],
                name: 'updateChainAdapter',
                outputs: [],
                stateMutability: 'nonpayable',
                type: 'function',
              },
            ] as const,
            functionName: 'updateChainAdapter',
            args: [chainInfo.chainId, targetAdapterAddress as Address],
          })

          console.log(
            kleur.green(`Chain ${chainInfo.chainId} adapter address updated, tx: ${hash}`),
          )

          // Wait for transaction confirmation
          const publicClient = await hre.viem.getPublicClient()
          await publicClient.waitForTransactionReceipt({ hash })
        } else {
          console.log(
            kleur.yellow(`Chain ${chainInfo.chainId} adapter address already correct, skipping`),
          )
        }
      } else {
        console.log(
          kleur.yellow(`No adapter address found for chain ${chainInfo.chainId}, skipping`),
        )
      }
    } catch (error) {
      console.error(
        kleur.red(`Error updating adapter address for chain ${chainInfo.chainId}:`),
        error,
      )
    }
  }
}

/**
 * Optimized Stargate contract validation with caching
 */
export async function validateStargateContract(contractAddress: string): Promise<boolean> {
  try {
    const publicClient = await hre.viem.getPublicClient()

    // First try OFT-style contract (has stargateType function)
    try {
      await publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: IStargateOFTABI,
        functionName: 'stargateType',
      })
      return true
    } catch {
      // Try Pool-style contract (has token function)
      try {
        await publicClient.readContract({
          address: contractAddress as `0x${string}`,
          abi: IStargatePoolABI,
          functionName: 'token',
        })
        return true
      } catch {
        // Try common Stargate functions
        try {
          await publicClient.readContract({
            address: contractAddress as `0x${string}`,
            abi: IStargateCommonABI,
            functionName: 'localDecimals',
          })
          return true
        } catch {
          // Final check: just verify it's a contract
          const code = await publicClient.getBytecode({
            address: contractAddress as `0x${string}`,
          })
          return code !== undefined && code !== '0x'
        }
      }
    }
  } catch {
    return false
  }
}

/**
 * Extract the actual bridge router address from the input parameter which can be either
 * a direct Address or an object containing the address
 */
export function extractBridgeRouterAddress(
  bridgeRouterAddress: Address | { bridgeRouterAddress: Address },
): Address {
  return typeof bridgeRouterAddress === 'object'
    ? bridgeRouterAddress.bridgeRouterAddress
    : bridgeRouterAddress
}
