import dotenv from 'dotenv'
import hre from 'hardhat'
import { Chain, createPublicClient, createWalletClient, Hex, http, WalletClient } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { CHAIN_CONFIG_MAP, RPC_URL_MAP } from '../chain/config'

dotenv.config({ path: '../../.env' })

const DEPLOYER_PRIV_KEY = process.env.DEPLOYER_PRIV_KEY as Hex

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
 * Get wallet client for transactions using the proper private key setup
 */
export async function getWalletClient(): Promise<WalletClient> {
  const networkName = hre.network.name
  const rpcUrl = RPC_URL_MAP[networkName as keyof typeof RPC_URL_MAP]
  const chainConfig = CHAIN_CONFIG_MAP[networkName as keyof typeof CHAIN_CONFIG_MAP]

  if (!rpcUrl) {
    throw new Error(`RPC URL not found for network ${networkName}`)
  }

  if (!chainConfig) {
    throw new Error(`Chain configuration not found for ${networkName}`)
  }

  const { walletClient } = createClients(chainConfig, rpcUrl)
  return walletClient
}
