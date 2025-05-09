import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import bridgeModule from '../../ignition/modules/bridge'
import { BridgeConfig, DeployedBridge } from '../../types/bridge-types'
import { ADDRESS_ZERO } from '../common/constants'

export async function deployBridgeRouter(config: any): Promise<{ address: Address }> {
  console.log(kleur.blue('Deploying bridge router'))
  const [deployer] = await hre.viem.getWalletClients()
  const currentChainId = Number(config.common.chainId)

  // For initial deployment, we only need the current chain
  const chainIds = [currentChainId]
  const routerAddresses = ['0x0000000000000000000000000000000000000000'] // Placeholder for current chain

  // Deploy using Ignition module
  const result = await hre.ignition.deploy(bridgeModule, {
    parameters: {
      BridgeModule: {
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        chainIds: [currentChainId],
        routerAddresses: ['0x0000000000000000000000000000000000000000'],
      },
    },
  })

  const bridgeRouter = result.bridgeRouter
  console.log(`BridgeRouter deployed at: ${bridgeRouter.address} on chain ${currentChainId}`)
  return { address: bridgeRouter.address as Address }
}

export async function deployBridgeQueue(
  bridgeRouterAddress: Address,
  config: any,
): Promise<{ address: Address }> {
  console.log(kleur.blue('Deploying queue'))

  // BridgeQueue is now deployed as part of the Ignition module
  const result = await hre.ignition.deploy(bridgeModule, {
    parameters: {
      BridgeModule: {
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        chainIds: [Number(config.common.chainId)],
        routerAddresses: ['0x0000000000000000000000000000000000000000'],
      },
    },
  })

  const bridgeQueue = result.bridgeQueue
  console.log(`BridgeQueue deployed at: ${bridgeQueue.address}`)

  return { address: bridgeQueue.address as Address }
}

export async function updateBridgeConfigs(
  bridgeRouterAddress: Address,
  config: any,
  allConfigs: Record<string, any>,
): Promise<void> {
  const [deployer] = await hre.viem.getWalletClients()
  const currentChainId = Number(config.common.chainId)
  const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)

  // Update all other chain configs with this chain's router address
  for (const [network, networkConfig] of Object.entries(allConfigs)) {
    const targetChainId = Number(networkConfig.common.chainId)

    // Skip current chain
    if (targetChainId === currentChainId) continue

    // Update the router address for this chain in the target chain's config
    if (!networkConfig.bridge) {
      networkConfig.bridge = {
        router: {
          chainIds: [],
          routerAddresses: [],
        },
      }
    }

    // Add or update the mapping
    const existingIndex = networkConfig.bridge.router.chainIds.indexOf(currentChainId)
    if (existingIndex >= 0) {
      networkConfig.bridge.router.routerAddresses[existingIndex] = bridgeRouterAddress
    } else {
      networkConfig.bridge.router.chainIds.push(currentChainId)
      networkConfig.bridge.router.routerAddresses.push(bridgeRouterAddress)
    }

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
  const currentChainId = Number(config.common.chainId)

  // Update mappings for all known chains
  for (const [network, networkConfig] of Object.entries(allConfigs)) {
    const targetChainId = Number(networkConfig.common.chainId)

    // Skip if no bridge config or no router address
    if (!networkConfig.bridge?.router?.routerAddresses) continue

    const index = networkConfig.bridge.router.chainIds.indexOf(targetChainId)
    if (index >= 0) {
      const routerAddress = networkConfig.bridge.router.routerAddresses[index]
      if (routerAddress !== '0x0000000000000000000000000000000000000000') {
        await bridgeRouter.write.setChainRouterAddress([targetChainId, routerAddress])
        console.log(`Updated mapping for chain ${targetChainId} to ${routerAddress}`)
      }
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

  const parameters = {
    BridgeModule: {
      protocolAccessManager: networkConfig.deployedContracts.gov.protocolAccessManager.address,
      chainIds: [Number(networkConfig.common.chainId)],
      routerAddresses: ['0x0000000000000000000000000000000000000000'],
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
