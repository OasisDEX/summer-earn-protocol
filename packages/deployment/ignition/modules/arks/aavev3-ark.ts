import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create an AaveV3ArkModule for deploying the AaveV3Ark contract
 *
 * This function creates a module that deploys the AaveV3Ark contract, which integrates with the Aave V3 protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createAaveV3ArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const aaveV3Pool = m.getParameter('aaveV3Pool')
    const rewardsController = m.getParameter('rewardsController')
    const arkParams = m.getParameter('arkParams')

    const aaveV3Ark = m.contract('AaveV3Ark', [aaveV3Pool, rewardsController, arkParams])

    return { aaveV3Ark }
  })
}

/**
 * Type definition for the returned contract address
 */
export type AaveV3ArkContracts = {
  aaveV3Ark: { address: string }
}
