import hre from 'hardhat'
import kleur from 'kleur'
import { BaseConfig } from '../ignition/config/config-types'
import CoreModule, { CoreContracts } from '../ignition/modules/core'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'

/**
 * Main function to deploy the core contracts.
 * This function:
 * - Gets the configuration for the current network
 * - Deploys the core contracts using Hardhat Ignition
 * - Logs the deployment results
 */
export async function deployCore() {
  // Get the configuration for the current network
  const config = getConfigByNetwork(hre.network.name)

  // Deploy the core contracts
  const deployedCore = await deployCoreContracts(config)

  // Log the deployment results
  ModuleLogger.logCore(deployedCore)
}

/**
 * Deploys the core contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<CoreContracts>} The deployed core contracts.
 */
async function deployCoreContracts(config: BaseConfig): Promise<CoreContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  return (await hre.ignition.deploy(CoreModule, {
    parameters: {
      CoreModule: {
        swapProvider: config.core.swapProvider,
        treasury: config.core.treasury,
      },
    },
    deploymentId,
  })) as CoreContracts
}

// Execute the deployCore function and handle any errors
deployCore().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
