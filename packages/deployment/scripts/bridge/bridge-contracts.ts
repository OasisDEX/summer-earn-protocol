import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import bridgeModule from '../../ignition/modules/bridge'
import { BridgeConfig, DeployedBridge } from '../../types/bridge-types'
import { ADDRESS_ZERO } from '../common/constants'

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

  // Current chain ID to compare with
  const currentChainId = Number(networkConfig.common.chainId)

  // Add router addresses from other chains
  for (const [network, otherConfig] of Object.entries(allConfigs)) {
    // Skip if no common.chainId
    if (!otherConfig.common?.chainId) continue

    const otherChainId = Number(otherConfig.common.chainId)

    // Skip current chain
    if (otherChainId === currentChainId) continue

    // Check for bridge router in deployedContracts
    let routerAddress = null
    if (otherConfig.deployedContracts?.bridge?.bridgeRouter?.address) {
      routerAddress = otherConfig.deployedContracts.bridge.bridgeRouter.address
    }
    // Alternatively check in protocolSpecific (some configs have it there)
    else if (otherConfig.protocolSpecific?.bridge?.bridgeRouter?.address) {
      routerAddress = otherConfig.protocolSpecific.bridge.bridgeRouter.address
    }

    if (routerAddress && routerAddress !== ADDRESS_ZERO) {
      console.log(`Adding router for chain ${otherChainId}: ${routerAddress}`)
      chainIds.push(otherChainId)
      routerAddresses.push(routerAddress)
    }
  }

  const parameters = {
    BridgeModule: {
      protocolAccessManager: networkConfig.deployedContracts.gov.protocolAccessManager.address,
      chainIds,
      routerAddresses,
    },
  }
  console.log('parameters [debug]:', parameters)

  // Deploy using Ignition module
  const result = await hre.ignition.deploy(bridgeModule, {
    parameters,
  })

  return {
    bridgeRouter: { address: result.bridgeRouter.address as Address },
    bridgeQueue: { address: result.bridgeQueue.address as Address },
  }
}
