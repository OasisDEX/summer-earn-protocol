import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import stargateConfig from '../../../config/adapters/stargate.json'
import StargateAdapterModule from '../../../ignition/modules/adapters/stargate'
import { getSupportedChainsFromConfig, getWalletClient, waitForPendingTransactions } from './utils'

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

  // Deploy using Ignition module - 3 constructor parameters needed
  const deploymentResult = await hre.ignition.deploy(StargateAdapterModule, {
    parameters: {
      StargateAdapterModule: {
        crossChainRegistry,
        accessManager,
        lzEndpoint,
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
  const publicClient = await hre.viem.getPublicClient()

  const currentChainId = Number(networkConfig.common.chainId)
  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  // Map chain IDs to LayerZero EIDs for all supported remote chains
  let mappingsAdded = 0
  for (const chainInfo of supportedChains) {
    if (chainInfo.chainId === currentChainId) continue

    try {
      const currentEndpointId = Number(
        await stargateAdapter.read.chainToExternalId([chainInfo.chainId]),
      )

      if (currentEndpointId !== Number(chainInfo.endpointId)) {
        console.log(
          `Mapping chain ${chainInfo.chainId} -> EID ${chainInfo.endpointId} (current: ${currentEndpointId})`,
        )
        const hash = await walletClient.writeContract({
          address: getAddress(stargateAdapterAddress as `0x${string}`),
          abi: [
            {
              inputs: [
                { internalType: 'uint16', name: 'chainId', type: 'uint16' },
                { internalType: 'uint32', name: 'externalId', type: 'uint32' },
              ],
              name: 'mapExternalId',
              outputs: [],
              stateMutability: 'nonpayable',
              type: 'function',
            },
          ] as const,
          functionName: 'mapExternalId',
          args: [chainInfo.chainId, chainInfo.endpointId],
        })
        console.log(kleur.green(`Chain mapping updated, tx: ${hash}`))

        await publicClient.waitForTransactionReceipt({ hash })
        mappingsAdded++
      } else {
        console.log(
          kleur.yellow(`EID mapping for chain ${chainInfo.chainId} already correct, skipping`),
        )
      }
    } catch (error) {
      console.error(kleur.red(`Error adding chain ${chainInfo.chainId}:`), error)
    }
  }

  console.log(kleur.green(`Updated ${mappingsAdded} chain -> EID mappings`))

  // Only add delay if we actually added chains
  if (mappingsAdded > 0) {
    console.log(kleur.blue(`Added ${mappingsAdded} new chains, waiting for settlement...`))
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

      // Strict pre-validation: must be a Pool and its token() must match the local asset
      try {
        const poolToken = await publicClient.readContract({
          address: checksummedStargateContract,
          abi: IStargatePoolABI,
          functionName: 'token',
        })
        const matches = String(poolToken).toLowerCase() === checksummedLocalAddress.toLowerCase()
        if (!matches) {
          console.log(
            kleur.yellow(
              `Skipping ${assetSymbol}: Stargate pool token ${poolToken} does not match local asset ${checksummedLocalAddress}`,
            ),
          )
          continue
        }
      } catch (e) {
        console.log(
          kleur.yellow(
            `Skipping ${assetSymbol}: Contract ${checksummedStargateContract} does not expose token() like a Stargate Pool`,
          ),
        )
        continue
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
          // Ensure tx is mined before proceeding to avoid nonce/fee conflicts
          await publicClient.waitForTransactionReceipt({ hash })
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

  // Note: StargateAdapter uses hardcoded taxi mode for all transfers
  // No configuration needed for transport mode

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
      // Ensure pending transactions are settled before sending governance-protected tx
      await waitForPendingTransactions()

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
      await publicClient.waitForTransactionReceipt({ hash })
    } else {
      console.log(
        kleur.yellow(
          `Stargate V2 adapter already registered with bridge router, skipping registration`,
        ),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error registering adapter with bridge router:'), error)
    // Do not swallow the error: surface it so the deploy flow fails visibly
    throw error
  }
}

/**
 * Update adapter addresses for cross-chain support after all adapters are deployed
 */
export async function updateStargateAdapterAddresses(
  stargateAdapterAddress: Address,
  allNetworkConfigs: Record<string, any>,
): Promise<void> {
  console.log(kleur.blue('Verifying Stargate adapter chain -> EID mappings'))

  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    getAddress(stargateAdapterAddress as `0x${string}`),
  )

  // Get wallet client for transactions using proper setup
  const walletClient = await getWalletClient()
  const publicClient = await hre.viem.getPublicClient()

  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  for (const chainInfo of supportedChains) {
    try {
      const currentEndpointId = Number(
        await stargateAdapter.read.chainToExternalId([chainInfo.chainId]),
      )
      if (currentEndpointId !== Number(chainInfo.endpointId)) {
        console.log(
          `Remapping chain ${chainInfo.chainId} to EID ${chainInfo.endpointId} (current: ${currentEndpointId})`,
        )
        const hash = await walletClient.writeContract({
          address: getAddress(stargateAdapterAddress as `0x${string}`),
          abi: [
            {
              inputs: [
                { internalType: 'uint16', name: 'chainId', type: 'uint16' },
                { internalType: 'uint32', name: 'externalId', type: 'uint32' },
              ],
              name: 'mapExternalId',
              outputs: [],
              stateMutability: 'nonpayable',
              type: 'function',
            },
          ] as const,
          functionName: 'mapExternalId',
          args: [chainInfo.chainId, chainInfo.endpointId],
        })
        await publicClient.waitForTransactionReceipt({ hash })
      } else {
        console.log(
          kleur.yellow(`EID mapping for chain ${chainInfo.chainId} already correct, skipping`),
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
