import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, Chain, createPublicClient, createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { getConfigByNetwork } from '../helpers/config-handler'
import { loadCrossChainConfig } from '../helpers/cross-chain-config'

// ABI for the setSourceChainArk function
const FLEET_PROXY_ABI = [
  {
    inputs: [{ internalType: 'address', name: '_sourceChainArk', type: 'address' }],
    name: 'setSourceChainArk',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

/**
 * Updates the FleetProxy on the satellite chain with the CrossChainArk address
 * from the source chain using viem directly.
 *
 * This script should be run on the satellite chain after the CrossChainArk has been deployed
 * on the source chain.
 */
export async function updateFleetProxy() {
  console.log(kleur.green().bold('Starting FleetProxy update process...'))
  console.log(kleur.yellow('Note: This should be run on the satellite chain.'))

  // Ask about using bummer config
  const { useBummerConfig } = await prompts({
    type: 'confirm',
    name: 'useBummerConfig',
    message: 'Do you want to use bummer (test) config?',
    initial: false,
  })

  // Get the current chain configuration
  const config = getConfigByNetwork(
    hre.network.name,
    {
      common: true,
      gov: true,
      bridge: true,
    },
    useBummerConfig,
  )

  // Get fleet configuration
  let fleetDefinition
  try {
    fleetDefinition = await getFleetConfig()
  } catch (error) {
    console.error(
      kleur.red('Fleet configuration not found. Please create a fleet configuration first.'),
    )
    throw error
  }

  // Load cross-chain config
  const crossChainConfig = loadCrossChainConfig(fleetDefinition.fleetName)
  if (!crossChainConfig) {
    console.error(kleur.red('Cross-chain configuration not found.'))
    console.error(kleur.red('You need to deploy FleetProxy and CrossChainArk first.'))
    throw new Error('Cross-chain config not found')
  }

  // Check if we have both addresses
  if (!crossChainConfig.fleetProxyAddress || !crossChainConfig.crossChainArkAddress) {
    console.error(kleur.red('Missing addresses in cross-chain config.'))
    if (!crossChainConfig.fleetProxyAddress) {
      console.error(kleur.red('FleetProxy address is missing. Deploy FleetProxy first.'))
    }
    if (!crossChainConfig.crossChainArkAddress) {
      console.error(kleur.red('CrossChainArk address is missing. Deploy CrossChainArk first.'))
    }
    throw new Error('Missing required addresses')
  }

  // Ask for confirmation
  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Update FleetProxy at ${crossChainConfig.fleetProxyAddress} with CrossChainArk address ${crossChainConfig.crossChainArkAddress}?`,
    initial: false,
  })

  if (!confirmed) {
    console.log(kleur.red('Update cancelled by user.'))
    return
  }

  // Ask for private key
  const { privateKey } = await prompts({
    type: 'password',
    name: 'privateKey',
    message: 'Enter your private key (starts with 0x):',
    validate: (value) => (/^0x[a-fA-F0-9]{64}$/.test(value) ? true : 'Invalid private key format'),
  })

  if (!privateKey) {
    console.log(kleur.red('No private key provided. Operation cancelled.'))
    return
  }

  try {
    console.log(kleur.yellow('Updating FleetProxy with CrossChainArk address...'))

    // Create account from private key
    const account = privateKeyToAccount(privateKey as `0x${string}`)

    // Get the chain ID from hardhat network
    const chainId = Number(await getChainIdFromNetwork())

    // Get RPC URL, fallback to a default if not available
    const rpcUrl =
      (hre.network.config as any).url || `https://${hre.network.name}.infura.io/v3/your-api-key`

    // Create a minimal chain config
    const chain: Chain = {
      id: chainId,
      name: hre.network.name,
      nativeCurrency: {
        decimals: 18,
        name: 'Ether',
        symbol: 'ETH',
      },
      rpcUrls: {
        default: { http: [rpcUrl] },
        public: { http: [rpcUrl] },
      },
    }

    // Create public client
    const publicClient = createPublicClient({
      chain,
      transport: http(rpcUrl),
    })

    // Create wallet client with account
    const walletClient = createWalletClient({
      account,
      chain,
      transport: http(rpcUrl),
    })

    // Call the contract function
    const hash = await walletClient.writeContract({
      address: crossChainConfig.fleetProxyAddress as Address,
      abi: FLEET_PROXY_ABI,
      functionName: 'setSourceChainArk',
      args: [crossChainConfig.crossChainArkAddress as Address],
      chain, // Add chain parameter explicitly
    })

    console.log(kleur.green('Transaction sent!'))
    console.log(kleur.yellow('Transaction Hash:'), hash)

    // Wait for transaction
    console.log(kleur.yellow('Waiting for transaction confirmation...'))
    const receipt = await publicClient.waitForTransactionReceipt({ hash })

    if (receipt.status === 'success') {
      console.log(kleur.green().bold('FleetProxy successfully updated!'))
    } else {
      console.error(kleur.red('Transaction failed!'))
      console.error('Receipt:', receipt)
    }
  } catch (error) {
    console.error(kleur.red('Error updating FleetProxy:'))
    console.error(error)
    throw error
  }
}

/**
 * Helper function to get chain ID from the current network
 */
async function getChainIdFromNetwork(): Promise<number> {
  // Use hardhat's provider to get chain ID
  const provider = hre.network.provider

  // Different ways to get chain ID depending on provider type
  try {
    // Try directly if it's a number
    if (typeof hre.network.config.chainId === 'number') {
      return hre.network.config.chainId
    }

    // Try RPC call
    const chainIdHex = await provider.request({ method: 'eth_chainId', params: [] })
    return parseInt(chainIdHex as string, 16)
  } catch (error) {
    console.error('Error getting chain ID:', error)
    throw error
  }
}

// Direct invocation
if (require.main === module) {
  updateFleetProxy().catch((error) => {
    console.error(kleur.red('Error during FleetProxy update:'))
    console.error(error)
    process.exit(1)
  })
}
