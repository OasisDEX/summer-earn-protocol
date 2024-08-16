import hre from 'hardhat'
import CoreModule, { CoreContracts } from '../ignition/modules/core'
import { getConfigByNetwork } from './config-handler'
import { ModuleLogger } from './module-logger'

export async function deployCore() {
  const config = getConfigByNetwork(hre.network.name)
  const deployedCore = (await hre.ignition.deploy(CoreModule, {
    parameters: {
      CoreModule: {
        swapProvider: config.swapProvider,
        treasury: config.treasury,
      },
    },
  })) as CoreContracts

  // Logging
  ModuleLogger.logCore(deployedCore)
}

deployCore().catch((error) => {
  console.error(error)
  process.exit(1)
})
