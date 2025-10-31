import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import bridgeModule from '../../ignition/modules/bridge'
import { DeployedBridge } from '../../types/bridge-types'
import { BaseConfig } from '../../types/config-types'
import { getAccessManagerAddress } from '../lib/config/getters'
import { ADDRESS_ZERO } from '../lib/infrastructure/constants'

/**
 * Check if address exists and is not zero
 */
function hasValidAddress(address?: string): boolean {
  return !!(address && address !== ADDRESS_ZERO)
}

export async function deployBridgeContracts(networkConfig: BaseConfig): Promise<DeployedBridge> {
  console.log(kleur.blue('Deploying bridge contracts'))

  // Validate required configuration
  const protocolAccessManager = getAccessManagerAddress(networkConfig)

  if (!networkConfig.common.chainId) {
    throw new Error('Chain ID is not configured')
  }

  // Check what exists in config
  const bridgeConfig = networkConfig.deployedContracts.bridge
  const routerExists = hasValidAddress(bridgeConfig?.bridgeRouter?.address)
  const registryExists = hasValidAddress(bridgeConfig?.crossChainRegistry?.address)

  console.log(kleur.blue('Deployment status check:'))
  console.log(
    `- BridgeRouter: ${routerExists ? kleur.green('EXISTS') : kleur.yellow('NEEDS DEPLOYMENT')}`,
  )
  console.log(
    `- CrossChainRegistry: ${registryExists ? kleur.green('EXISTS') : kleur.yellow('NEEDS DEPLOYMENT')}`,
  )

  if (routerExists && registryExists) {
    // All exist in config
    console.log(kleur.green('All contracts already configured'))
    return {
      bridgeRouter: { address: bridgeConfig!.bridgeRouter.address as Address },
      crossChainRegistry: { address: bridgeConfig!.crossChainRegistry.address as Address },
    }
  }

  if (!routerExists || !registryExists) {
    // One or both don't exist, deploy both using original module
    console.log(kleur.blue('Deploying BridgeRouter and CrossChainRegistry'))

    const parameters = {
      BridgeModule: {
        protocolAccessManager,
      },
    }

    const result = await hre.ignition.deploy(bridgeModule, {
      parameters,
    })

    return {
      bridgeRouter: { address: result.bridgeRouter.address as Address },
      crossChainRegistry: { address: result.crossChainRegistry.address as Address },
    }
  }

  throw new Error('Unexpected deployment state')
}
