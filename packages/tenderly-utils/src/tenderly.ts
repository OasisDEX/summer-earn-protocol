import axios from 'axios'
import { ethers, JsonRpcProvider } from 'ethers'
import { IAccountGuardAbi, IAccountImplementationAbi } from './abis'
import { NetworkName, tokenAddresses } from './utils'
import { getTokenDecimals } from './getTokenDecimals'

// TODO: use 'viem' instead of Ethers.js

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const { TENDERLY_USER, TENDERLY_PROJECT, TENDERLY_ACCESS_KEY } = process.env as any

if (!TENDERLY_USER || !TENDERLY_PROJECT || !TENDERLY_ACCESS_KEY) {
  throw new Error('Tenderly environment variables not set')
}

const TENDERLY_FORK_API = `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork`

const request = axios.create({
  baseURL: 'https://api.tenderly.co/api/v1',
  headers: {
    'X-Access-Key': TENDERLY_ACCESS_KEY,
    'Content-Type': 'application/json',
  },
})

export const createFork = async ({
  network,
  atBlock,
}: {
  network: NetworkName
  atBlock: number
}) => {
  const network_ids = {
    mainnet: '1',
    optimism: '10',
    arbitrum: '42161',
    base: '8453',
  }
  const network_id = network_ids[network]

  return await request.post(TENDERLY_FORK_API, { network_id, block_number: atBlock })
}

export const deleteFork = async (forkId: string) => {
  return await request.delete(`${TENDERLY_FORK_API}/${forkId}`)
}

export const getSimulations = async (forkId: string) => {
  return await request.get(`${TENDERLY_FORK_API}/${forkId}/transactions?page=1&perPage=20`)
}

export const verifyTxReceiptStatusSuccess = async (forkId: string) => {
  const resp = await getSimulations(forkId)
  const autoBuyTxReceiptStatus = await resp.data.fork_transactions[0].receipt.status
  return autoBuyTxReceiptStatus === '0x1'
}

export const getTxCount = async (forkId: string) => {
  const resp = await getSimulations(forkId)
  const txCount: number = resp.data.fork_transactions.length
  return txCount
}

export const setETHBalance = async ({
  forkId,
  balance,
  walletAddress,
}: {
  forkId: string
  balance: string
  walletAddress: string
}) => {
  const provider = new JsonRpcProvider(`https://rpc.tenderly.co/fork/${forkId}`)
  const WALLETS = [walletAddress]
  await provider.send('tenderly_setBalance', [
    WALLETS,
    ethers.toQuantity(ethers.parseUnits(balance, 'ether')),
  ])
}

export const setERC20TokenBalance = async ({
  forkId,
  network,
  token,
  balance,
  walletAddress,
}: {
  forkId: string
  network: NetworkName
  token: string
  balance: string
  walletAddress: string
}) => {
  const provider = new JsonRpcProvider(`https://rpc.tenderly.co/fork/${forkId}`)
  const decimals = getTokenDecimals(token)
  await provider.send('tenderly_setErc20Balance', [
    tokenAddresses[network][token],
    walletAddress,
    ethers.toQuantity(ethers.parseUnits(balance, decimals)),
  ])
}

/**
 *
 * @param account Addres of the proxy to take ownershipt of
 * @param newOwner New wallet address
 */
export const changeAccountOwner = async ({
  account,
  newOwner,
  forkId,
}: {
  account: string
  newOwner: string
  forkId: string
}): Promise<boolean> => {
  const provider = new JsonRpcProvider(`https://rpc.tenderly.co/fork/${forkId}`)
  const accountInterface = new ethers.Interface(IAccountImplementationAbi)
  const guardInterface = new ethers.Interface(IAccountGuardAbi)
  const contract = new ethers.Contract(account, accountInterface, provider)
  const guard = await contract.guard()
  const owner = await contract.owner()
  const encoded = guardInterface.encodeFunctionData('changeOwner', [newOwner, account])
  try {
    await provider.send('eth_sendTransaction', [{ from: owner, to: guard, input: encoded }])
    return true
  } catch (error) {
    return false
  }
}
