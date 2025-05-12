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

  return {
    bridgeRouter: { address: result.bridgeRouter.address as Address },
    bridgeQueue: { address: result.bridgeQueue.address as Address },
  }
}
