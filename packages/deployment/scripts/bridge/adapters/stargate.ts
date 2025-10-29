import hre from 'hardhat'
import kleur from 'kleur'
import { Address, WalletClient, getAddress } from 'viem'
import StargateAdapterModule from '../../../ignition/modules/adapters/stargate'
import {
  getAccessManagerAddress,
  getChainIdFromConfig,
  getCrossChainRegistryAddress,
  getLayerZeroEndpoint,
} from '../../lib/config/getters'
import { waitForTransactionConfirmation, writeContractTx } from '../../lib/contracts/transactions'
import { BRIDGE_ROUTER_REGISTER_ADAPTER_ABI } from './abis'
import {
  AssetConfigurationParams,
  StargateAdapterContract,
  configureSupportedAssets,
  logAssetConfigurationResults,
} from './stargate-asset-service'
import {
  ChainConfigurationParams,
  configureSupportedChains,
  logChainConfigurationResults,
} from './stargate-chain-service'
import { StargateContractValidator } from './stargate-validation-service'
import { isAdapterRegistered, validateBridgeConfig } from './transaction-helpers'
import { BaseConfig, NetworkConfigMap } from './types'
import { getSupportedChainsFromConfig, getWalletClient } from './utils'

/**
 * Deploy Stargate adapter using Ignition module
 */
export async function deployStargateAdapter(
  networkConfig: BaseConfig,
  allNetworkConfigs?: NetworkConfigMap,
): Promise<Address> {
  console.log(kleur.blue('Deploying Stargate V2 adapter using Ignition module'))

  // Get current chain ID
  const chainId = getChainIdFromConfig(networkConfig)

  // Get the crossChainRegistry address from network config
  const crossChainRegistry = getCrossChainRegistryAddress(networkConfig)

  // Get the access manager address from network config
  const accessManager = getAccessManagerAddress(networkConfig)

  // Get LayerZero endpoint from network config
  const lzEndpoint = getLayerZeroEndpoint(networkConfig)

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
 * Register adapter with bridge router
 */
async function registerWithBridgeRouter(
  walletClient: WalletClient,
  stargateAdapterAddress: Address,
  bridgeRouterAddress: Address,
): Promise<void> {
  try {
    const alreadyRegistered = await isAdapterRegistered(bridgeRouterAddress, stargateAdapterAddress)

    if (!alreadyRegistered) {
      const hash = await writeContractTx(
        walletClient,
        bridgeRouterAddress,
        BRIDGE_ROUTER_REGISTER_ADAPTER_ABI,
        'registerAdapter',
        [getAddress(stargateAdapterAddress as `0x${string}`)],
      )
      console.log(kleur.green(`Stargate V2 adapter registered with bridge router, tx: ${hash}`))
      await waitForTransactionConfirmation(hash)
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
 * Configure supported chains and assets for Stargate V2 adapter
 */
export async function configureStargateAdapter(
  stargateAdapterAddress: Address,
  bridgeRouterAddress: Address,
  networkConfig: BaseConfig,
  allNetworkConfigs?: NetworkConfigMap,
): Promise<void> {
  console.log(kleur.blue('Configuring Stargate V2 adapter'))

  validateBridgeConfig(networkConfig)

  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    getAddress(stargateAdapterAddress as `0x${string}`),
  )

  const walletClient = await getWalletClient()
  const currentChainId = Number(networkConfig.common.chainId)
  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  // Debug logging
  console.log(
    'allNetworkConfigs keys:',
    allNetworkConfigs ? Object.keys(allNetworkConfigs) : 'undefined',
  )
  console.log('supportedChains:', supportedChains)

  // Create validator instance
  const validator = new StargateContractValidator()

  // Configure supported chains
  const chainParams: ChainConfigurationParams = {
    stargateAdapter,
    walletClient,
    stargateAdapterAddress,
    currentChainId,
    supportedChains,
    allNetworkConfigs,
  }

  const chainResult = await configureSupportedChains(chainParams)
  logChainConfigurationResults(chainResult)

  // Configure supported assets
  const assetParams: AssetConfigurationParams = {
    stargateAdapter: stargateAdapter as unknown as StargateAdapterContract,
    walletClient,
    stargateAdapterAddress,
    currentChainId,
    networkConfig,
    validator,
  }

  const assetResult = await configureSupportedAssets(assetParams)
  logAssetConfigurationResults(assetResult)

  // Register adapter with bridge router
  await registerWithBridgeRouter(walletClient, stargateAdapterAddress, bridgeRouterAddress)
}

/**
 * Update adapter addresses for cross-chain support after all adapters are deployed
 */
export async function updateStargateAdapterAddresses(
  stargateAdapterAddress: Address,
  allNetworkConfigs: NetworkConfigMap,
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
 * @deprecated Use StargateContractValidator class instead
 */
export async function validateStargateContract(contractAddress: string): Promise<boolean> {
  const validator = new StargateContractValidator()
  return validator.validateContract(contractAddress)
}
