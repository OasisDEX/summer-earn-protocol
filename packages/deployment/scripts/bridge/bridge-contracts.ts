import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import bridgeModule from '../../ignition/modules/bridge'
import { BridgeConfig, DeployedBridge } from '../../types/bridge-types'
import { ADDRESS_ZERO } from '../common/constants'

export async function updateBridgeConfigs(
  bridgeRouterAddress: Address,
  config: any,
  allConfigs: Record<string, any>,
): Promise<void> {
  const currentChainId = Number(config.common.chainId)

  // Update all other chain configs with this chain's router address
  for (const [network, networkConfig] of Object.entries(allConfigs)) {
    const targetChainId = Number(networkConfig.common.chainId)

    // Skip current chain
    if (targetChainId === currentChainId) continue

    // Update the router address for this chain in the target chain's config
    if (!networkConfig.bridge) {
      networkConfig.bridge = {
        bridgeRouter: { address: ADDRESS_ZERO },
        bridgeQueue: { address: ADDRESS_ZERO },
      }
    }

    // Update the bridgeRouter address
    networkConfig.bridge.bridgeRouter.address = bridgeRouterAddress

    console.log(
      `Updated config for chain ${targetChainId} with router address ${bridgeRouterAddress}`,
    )
  }
}

export async function updateRouterMappings(
  bridgeRouterAddress: Address,
  config: any,
  allConfigs: Record<string, any>,
): Promise<void> {
  const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)

  // Update mappings for all known chains
  for (const [network, networkConfig] of Object.entries(allConfigs)) {
    const targetChainId = Number(networkConfig.common.chainId)

    // Skip current chain
    if (targetChainId === Number(config.common.chainId)) continue

    // Skip if no bridge config or no router address
    if (!networkConfig.bridge?.bridgeRouter?.address) continue

    const routerAddress = networkConfig.bridge.bridgeRouter.address
    if (routerAddress !== ADDRESS_ZERO) {
      await bridgeRouter.write.setChainRouterAddress([targetChainId, routerAddress])
      console.log(`Updated mapping for chain ${targetChainId} to ${routerAddress}`)
    }
  }
}

export async function deployBridgeContracts(
  config: BridgeConfig,
  networkConfig: any,
  allConfigs: Record<string, any>,
): Promise<DeployedBridge> {
  console.log(kleur.blue('Deploying bridge contracts'))

  // Validate required configuration
  if (networkConfig.deployedContracts.gov.protocolAccessManager.address === ADDRESS_ZERO) {
    throw new Error('ProtocolAccessManager is not deployed')
  }

  if (!networkConfig.common.chainId) {
    throw new Error('Chain ID is not configured')
  }

  // Get router addresses from other chains
  const chainIds: number[] = []
  const routerAddresses: string[] = []

  // Add router addresses from other chains
  for (const [, networkConfig] of Object.entries(allConfigs)) {
    const targetChainId = Number(networkConfig.common.chainId)
    if (targetChainId === Number(networkConfig.common.chainId)) continue

    if (
      networkConfig.bridge?.bridgeRouter?.address &&
      networkConfig.bridge.bridgeRouter.address !== ADDRESS_ZERO
    ) {
      chainIds.push(targetChainId)
      routerAddresses.push(networkConfig.bridge.bridgeRouter.address)
    }
  }

  const parameters = {
    BridgeModule: {
      protocolAccessManager: networkConfig.deployedContracts.gov.protocolAccessManager.address,
      chainIds,
      routerAddresses,
    },
  }

  // Deploy using Ignition module
  const result = await hre.ignition.deploy(bridgeModule, {
    parameters,
  })

  // Update all other chain configs with this chain's router address
  await updateBridgeConfigs(result.bridgeRouter.address as Address, networkConfig, allConfigs)

  // Update this chain's router with all known mappings
  await updateRouterMappings(result.bridgeRouter.address as Address, networkConfig, allConfigs)

  return {
    bridgeRouter: { address: result.bridgeRouter.address as Address },
    bridgeQueue: { address: result.bridgeQueue.address as Address },
  }
}
