import hre from 'hardhat'
import { Address } from 'viem'
import { BridgeConfig, DeployedBridge } from '../../types/bridge-types'
import { validateAddress } from '../helpers/validation'

export async function deployBridgeRouter(
  chainIds: number[],
  routerAddresses: Address[],
  config: any,
): Promise<{ address: Address }> {
  const [deployer] = await hre.viem.getWalletClients()

  // Validate inputs
  if (chainIds.length !== routerAddresses.length) {
    throw new Error('Chain IDs and router addresses arrays must have the same length')
  }

  routerAddresses.forEach((addr, i) => {
    validateAddress(addr, `Router address for chain ${chainIds[i]}`)
  })

  // Deploy BridgeRouter
  const bridgeRouter = await hre.viem.deployContract('BridgeRouter', [
    config.deployedContracts.gov.protocolAccessManager.address,
    Address.ZERO, // BridgeQueue address will be set after deployment
    chainIds,
    routerAddresses,
  ])

  console.log(`BridgeRouter deployed at: ${bridgeRouter.address}`)
  return { address: bridgeRouter.address }
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

  return { address: bridgeQueue.address }
}

export async function deployBridgeContracts(
  config: BridgeConfig,
  networkConfig: any,
): Promise<DeployedBridge> {
  // Deploy BridgeRouter
  const bridgeRouter = await deployBridgeRouter(
    config.bridgeRouter.chainIds,
    config.bridgeRouter.routerAddresses,
    networkConfig,
  )

  // Deploy BridgeQueue
  const bridgeQueue = await deployBridgeQueue(bridgeRouter.address, networkConfig)

  return {
    bridgeRouter,
    bridgeQueue,
  }
}
