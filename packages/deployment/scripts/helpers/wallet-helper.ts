import dotenv from 'dotenv'
import { Chain, createPublicClient, createWalletClient, Hex, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

dotenv.config()

const PRIVATE_KEY = process.env.PRIVATE_KEY as Hex

export function createClients(chain: Chain, rpcUrl: string, privateKey?: Hex) {
  console.log('Creating clients for chain:', chain.name)
  console.log('RPC URL:', rpcUrl)
  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  })

  const _privateKey = privateKey || PRIVATE_KEY
  const account = privateKeyToAccount(`0x${_privateKey}`)
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  })

  return { publicClient, walletClient }
}
