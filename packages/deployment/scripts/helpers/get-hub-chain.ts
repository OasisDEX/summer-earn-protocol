import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'

/**
 * Get the hub chain name
 */
export function getHubChain(): string {
  return HUB_CHAIN_NAME
}

/**
 * Check if the chain is the hub chain
 * @param chainName - The name of the chain to check
 * @returns True if the chain is the hub chain, false otherwise
 */
export function isHubChain(chainName: string) {
  return chainName === HUB_CHAIN_NAME
}

/**
 * Check if the chain is a satellite chain
 * @param chainName - The name of the chain to check
 * @returns True if the chain is a satellite chain, false otherwise
 */
export function isSatelliteChain(chainName: string) {
  return chainName !== HUB_CHAIN_NAME
}
