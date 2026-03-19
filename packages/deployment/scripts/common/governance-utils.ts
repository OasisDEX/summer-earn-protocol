import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { Address, WalletClient } from 'viem'
import { GOVERNOR_ROLE } from './constants'

/**
 * Finds the first governor among the first 10 wallet clients.
 * @param hre - Hardhat Runtime Environment
 * @param protocolAccessManagerAddress - Address of the ProtocolAccessManager contract
 * @returns The governor wallet client if found, otherwise undefined
 */
export async function getGovernorClient(
  hre: HardhatRuntimeEnvironment,
  protocolAccessManagerAddress: Address,
): Promise<WalletClient | undefined> {
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )

  const publicClient = await hre.viem.getPublicClient()
  const walletClients = await hre.viem.getWalletClients()

  // Check up to 10 deployers
  const clientsToCheck = walletClients.slice(0, 10)

  // Use multicall to check roles for all clients at once
  const results = await publicClient.multicall({
    contracts: clientsToCheck.map((client) => ({
      address: protocolAccessManagerAddress,
      abi: protocolAccessManager.abi,
      functionName: 'hasRole',
      args: [GOVERNOR_ROLE, client.account.address],
    })),
  })

  // Find the first client that has the governor role
  for (let i = 0; i < results.length; i++) {
    if (results[i].status === 'success' && results[i].result === true) {
      return clientsToCheck[i] as WalletClient
    }
  }

  return undefined
}
