import dotenv from 'dotenv'
import { Chain, createPublicClient, createWalletClient, Hex, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

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
