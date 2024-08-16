import hre from 'hardhat'
import CoreModule, { CoreContracts } from '../ignition/modules/core'
import { getConfigByNetwork } from './config-handler'
import { BaseConfig } from './config-types'
import { ModuleLogger } from './module-logger'

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
  return (await hre.ignition.deploy(CoreModule, {
    parameters: {
      CoreModule: {
        swapProvider: config.core.swapProvider,
        treasury: config.core.treasury,
      },
    },
  })) as CoreContracts
}

// Execute the deployCore function and handle any errors
deployCore().catch((error) => {
  console.error(error)
  process.exit(1)
})
