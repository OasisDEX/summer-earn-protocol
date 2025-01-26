import dotenv from 'dotenv'
import { Chain, createPublicClient, createWalletClient, Hex, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

dotenv.config()

const PRIVATE_KEY = process.env.PRIVATE_KEY as Hex

export function createClients(chain: Chain, rpcUrl: string) {
  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  })

  const account = privateKeyToAccount(`0x${PRIVATE_KEY}`)
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  })

  return { publicClient, walletClient }
}
