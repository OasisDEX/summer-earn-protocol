import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import bridgeModule from '../../ignition/modules/bridge'
import { DeployedBridge } from '../../types/bridge-types'
import { ADDRESS_ZERO } from '../common/constants'

/**
 * Create a router-only deployment module for when queue already exists
 */
function createRouterOnlyModule() {
  return buildModule('RouterOnlyModule', (m) => {
    const protocolAccessManager = m.getParameter<Address>('protocolAccessManager')
    const existingBridgeQueue = m.getParameter<Address>('existingBridgeQueue')

    // Deploy only the BridgeRouter
    const bridgeRouter = m.contract('BridgeRouter', [
      protocolAccessManager,
      existingBridgeQueue, // Link to existing queue immediately
    ])

    return {
      bridgeRouter,
    }
  })
}

/**
 * Check if address exists and is not zero
 */
function hasValidAddress(address?: string): boolean {
  return !!(address && address !== ADDRESS_ZERO)
}

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

  const protocolAccessManager = networkConfig.deployedContracts.gov.protocolAccessManager.address

  // Check what exists in config
  const bridgeConfig = networkConfig.deployedContracts.bridge
  const queueExists = hasValidAddress(bridgeConfig?.bridgeQueue?.address)
  const routerExists = hasValidAddress(bridgeConfig?.bridgeRouter?.address)

  console.log(kleur.blue('Deployment status check:'))
  console.log(
    `- BridgeQueue: ${queueExists ? kleur.green('EXISTS') : kleur.yellow('NEEDS DEPLOYMENT')}`,
  )
  console.log(
    `- BridgeRouter: ${routerExists ? kleur.green('EXISTS') : kleur.yellow('NEEDS DEPLOYMENT')}`,
  )

  if (routerExists && queueExists) {
    // Both exist in config
    console.log(kleur.green('Both contracts already configured'))
    return {
      bridgeRouter: { address: bridgeConfig.bridgeRouter.address as Address },
      bridgeQueue: { address: bridgeConfig.bridgeQueue.address as Address },
    }
  }

  if (!routerExists && !queueExists) {
    // Neither exists, deploy both using original module
    console.log(kleur.blue('Deploying both BridgeRouter and BridgeQueue'))

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
      bridgeQueue: { address: result.bridgeQueue.address as Address },
    }
  }

  if (queueExists && !routerExists) {
    // Queue exists in config, need to deploy router only
    console.log(kleur.blue('BridgeQueue exists, deploying BridgeRouter only'))

    const existingQueueAddress = bridgeConfig.bridgeQueue.address as Address
    console.log(kleur.cyan('Existing BridgeQueue:'), existingQueueAddress)

    // Deploy router using router-only module
    const routerModule = createRouterOnlyModule()
    const result = await hre.ignition.deploy(routerModule, {
      parameters: {
        RouterOnlyModule: {
          protocolAccessManager,
          existingBridgeQueue: existingQueueAddress,
        },
      },
    })

    const newRouterAddress = result.bridgeRouter.address as Address
    console.log(kleur.green('New BridgeRouter deployed:'), newRouterAddress)

    // Now link the existing queue to the new router
    console.log(kleur.blue('Linking existing BridgeQueue to new BridgeRouter...'))
    try {
      const bridgeQueue = await hre.viem.getContractAt('BridgeQueue', existingQueueAddress)
      await bridgeQueue.write.setBridgeRouter([newRouterAddress])
      console.log(kleur.green('✓ BridgeQueue successfully linked to new BridgeRouter'))
    } catch (error) {
      console.error(kleur.red('Error linking contracts:'), error)
      throw new Error(
        'Failed to link BridgeQueue to new BridgeRouter. You may need to call setBridgeRouter manually.',
      )
    }

    return {
      bridgeRouter: { address: newRouterAddress },
      bridgeQueue: { address: existingQueueAddress },
    }
  }

  if (!queueExists && routerExists) {
    // Router exists, need to deploy queue only - less common scenario
    throw new Error(
      'Queue-only deployment not implemented. Please set both addresses to zero to deploy fresh.',
    )
  }

  throw new Error('Unexpected deployment state')
}
