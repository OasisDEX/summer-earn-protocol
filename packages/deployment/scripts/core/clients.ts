import dotenv from 'dotenv'
import hre from 'hardhat'
import { Chain, createPublicClient, createWalletClient, Hex, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { CHAIN_CONFIG_MAP, RPC_URL_MAP } from './chain'

dotenv.config({ path: '../../.env' })

const DEPLOYER_PRIV_KEY = process.env.DEPLOYER_PRIV_KEY as Hex

/**
 * Creates both public and wallet clients for a given chain
 * @param chain The chain configuration
 * @param rpcUrl The RPC URL for the chain
 * @param privateKey Optional private key (uses DEPLOYER_PRIV_KEY if not provided)
 * @returns Object containing publicClient and walletClient
 */
export function createClients(chain: Chain, rpcUrl: string, privateKey?: Hex) {
  console.log('Creating clients for chain:', chain.name)
  console.log('RPC URL:', rpcUrl)
  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  })

  const _privateKey = privateKey || DEPLOYER_PRIV_KEY
  const account = privateKeyToAccount(`0x${_privateKey}`)
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  })

  return { publicClient, walletClient }
}

/**
 * Get a public client for a specific chain
 * @param chainName The name of the chain
 * @returns A public client configured for the specified chain
 */
export async function getChainPublicClient(
  chainName: string,
): Promise<ReturnType<typeof createPublicClient>> {
  // If it's the current chain, use the Hardhat client
  if (chainName === hre.network.name) {
    return await hre.viem.getPublicClient()
  }

  // Get the RPC URL for the chain
  const rpcUrl = RPC_URL_MAP[chainName as keyof typeof RPC_URL_MAP]

  if (!rpcUrl) {
    throw new Error(
      `No RPC URL found for chain ${chainName}. Set RPC_URL_${chainName.toUpperCase()} environment variable.`,
    )
  }

  // Get chain configuration
  const chainConfig = CHAIN_CONFIG_MAP[chainName as keyof typeof CHAIN_CONFIG_MAP]

  if (!chainConfig) {
    throw new Error(`Chain configuration not found for ${chainName}`)
  }

  // Create a public client for the specified chain
  return createPublicClient({
    chain: chainConfig as Chain,
    transport: http(rpcUrl),
  })
}
