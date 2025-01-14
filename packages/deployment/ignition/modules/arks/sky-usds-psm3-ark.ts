import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SkyUsdsPsm3ArkModule for deploying the SkyUsdsPsm3Ark contract
 *
 * This function creates a module that deploys the SkyUsdsPsm3Ark contract, which integrates with the Sky protocol using PSM3.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSkyUsdsPsm3ArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const psm3 = m.getParameter('psm3')
    const susds = m.getParameter('susds')
    const arkParams = m.getParameter('arkParams')

    const skyUsdsPsm3Ark = m.contract('SkyUsdsPsm3Ark', [psm3, susds, arkParams])

    return { skyUsdsPsm3Ark }
  })
}

/**
 * Type definition for the returned contract address
 */
export type SkyUsdsPsm3ArkContracts = {
  skyUsdsPsm3Ark: { address: string }
}
