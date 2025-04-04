import hre from 'hardhat'
import { Address } from 'viem'
import { CHAIN_MAP_BY_ID } from '../common/chain-config-map'
import { getConfigByNetwork } from './config-handler'

/**
 * Gets the hub chain ID from the SummerGovernor contract and determines if
 * the current chain is the hub chain
 * @returns An object containing the hubChainId and whether the current chain is the hub chain
 */
export async function getHubChainInfo() {
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: true, core: false })

  // Get the SummerGovernor contract
  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernor' as string,
    config.deployedContracts.gov.summerGovernor.address as Address,
  )

  // Read the hub chain ID from the contract
  const hubChainId = await summerGovernor.read.hubChainId()

  // Determine if we're on the hub chain
  const currentChainId = hre.network.config.chainId
  const isHubChain = hubChainId === currentChainId

  return {
    hubChainId,
    isHubChain,
    hubChainName: getChainNameById(hubChainId as number),
    currentChainId,
    currentChainName: hre.network.name,
  }
}

/**
 * Gets the chain name based on chain ID
 * @param chainId The chain ID to look up
 * @returns The name of the chain
 */
export function getChainNameById(chainId: number): string {
  const chainName = CHAIN_MAP_BY_ID[chainId]?.name
  if (!chainName) {
    throw new Error(`Chain name not found for chain ID: ${chainId}`)
  }

  return chainName
}

/**
 * Gets chain ID from network name or the current network
 * @param networkName Optional network name
 * @returns The chain ID
 */
export function getChainId(networkName?: string): number {
  const network = networkName || hre.network.name

  const chainId = CHAIN_MAP_BY_ID[network as keyof typeof CHAIN_MAP_BY_ID]?.id

  if (!chainId) {
    throw new Error(`Unknown network name: ${network}`)
  }

  return chainId
}
