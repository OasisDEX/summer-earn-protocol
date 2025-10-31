import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import { getChainConfigs } from '../chain/config'
import { BaseConfig, ChainInfo, NetworkConfigMap } from '../../../x-chain/adapters/types'

/**
 * Helper function to get all supported chains with LayerZero endpoint IDs from config
 */
export function getSupportedChainsFromConfig(allNetworkConfigs?: NetworkConfigMap): ChainInfo[] {
  if (!allNetworkConfigs) {
    // Get chains from our standard chain configs
    const configs = getChainConfigs()

    return Object.values(configs)
      .filter(({ config }) => config.common?.layerZero?.eID)
      .map(({ chain, config }) => ({
        chainId: chain.id,
        endpointId: Number(config.common.layerZero.eID),
      }))
  }

  // Extract from provided config
  const chains: ChainInfo[] = []
  for (const [, config] of Object.entries(allNetworkConfigs)) {
    const baseConfig = config as BaseConfig
    if (baseConfig?.common?.chainId && baseConfig?.common?.layerZero?.eID) {
      chains.push({
        chainId: Number(baseConfig.common.chainId),
        endpointId: Number(baseConfig.common.layerZero.eID),
      })
    }
  }

  return chains
}

/**
 * Check if adapter is already registered with bridge router
 */
export async function isAdapterRegistered(
  bridgeRouterAddress: Address,
  adapterAddress: Address,
): Promise<boolean> {
  try {
    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as string,
      getAddress(bridgeRouterAddress as `0x${string}`),
    )

    return Boolean(
      await bridgeRouter.read.isValidAdapter([getAddress(adapterAddress as `0x${string}`)]),
    )
  } catch (error) {
    console.error(kleur.red('Error checking if adapter is registered:'), error)
    return false
  }
}

