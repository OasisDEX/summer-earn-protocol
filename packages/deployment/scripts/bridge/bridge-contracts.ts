import hre from 'hardhat'
import { Address } from 'viem'
import { BridgeConfig, DeployedBridge } from '../../types/bridge-types'

export async function deployBridgeRouter(config: any): Promise<{ address: Address }> {
  const [deployer] = await hre.viem.getWalletClients()
  const currentChainId = Number(config.common.chainId)

  // For initial deployment, we only need the current chain
  const chainIds = [currentChainId]
  const routerAddresses = ['0x0000000000000000000000000000000000000000'] // Placeholder for current chain

  // Deploy BridgeRouter
  const bridgeRouter = await hre.viem.deployContract('BridgeRouter', [
    config.deployedContracts.gov.protocolAccessManager.address,
    '0x0000000000000000000000000000000000000000', // BridgeQueue address will be set after deployment
    chainIds,
    routerAddresses,
  ])

  console.log(`BridgeRouter deployed at: ${bridgeRouter.address} on chain ${currentChainId}`)
  return { address: bridgeRouter.address as Address }
}

export async function deployBridgeQueue(
  bridgeRouterAddress: Address,
  config: any,
): Promise<{ address: Address }> {
  const [deployer] = await hre.viem.getWalletClients()

  // Deploy BridgeQueue
  const bridgeQueue = await hre.viem.deployContract('BridgeQueue', [
    config.deployedContracts.gov.protocolAccessManager.address,
    bridgeRouterAddress,
    deployer.account.address, // Initial queue manager
  ])

  console.log(`BridgeQueue deployed at: ${bridgeQueue.address}`)

  // Set BridgeQueue in BridgeRouter
  const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)
  await bridgeRouter.write.setBridgeQueue([bridgeQueue.address])

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
  const [deployer] = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)
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
  // Deploy BridgeRouter
  const bridgeRouter = await deployBridgeRouter(networkConfig)

  // Deploy BridgeQueue
  const bridgeQueue = await deployBridgeQueue(bridgeRouter.address, networkConfig)

  // Update all other chain configs with this chain's router address
  await updateBridgeConfigs(bridgeRouter.address, networkConfig, allConfigs)

  // Update this chain's router with all known mappings
  await updateRouterMappings(bridgeRouter.address, networkConfig, allConfigs)

  return {
    bridgeRouter,
    bridgeQueue,
  }
}
