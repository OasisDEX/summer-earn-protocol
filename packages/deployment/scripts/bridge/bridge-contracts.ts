import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import bridgeModule from '../../ignition/modules/bridge'
import { DeployedBridge } from '../../types/bridge-types'
import { ADDRESS_ZERO } from '../common/constants'

export async function deployBridgeContracts(
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
