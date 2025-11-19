import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a CrossChainManagerModule for deploying the CrossChainManager contract
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createCrossChainManagerModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const configurationManager = m.getParameter('configurationManager')
    const validationRegistry = m.getParameter('validationRegistry')
    const accessManager = m.getParameter('accessManager')

    const crossChainManager = m.contract('CrossChainManager', [
      configurationManager,
      validationRegistry,
      accessManager,
    ])

    return { crossChainManager }
  })
}

// Legacy-style export for convenience
export const CrossChainManagerModule = createCrossChainManagerModule('CrossChainManagerModule')

/**
 * Type definition for the returned contract address
 */
export type CrossChainManagerContract = {
  crossChainManager: { address: string }
}
