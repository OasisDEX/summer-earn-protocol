import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a CrossChainArkLiteModule for deploying the CrossChainArkLite contract
 *
 * This function creates a module that deploys the CrossChainArkLite contract, which is a lightweight
 * Ark that holds underlying assets and can perform arbitrary validated calls.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createCrossChainArkLiteModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const arkParams = m.getParameter('arkParams')
    const validationRegistry = m.getParameter('validationRegistry')

    const crossChainArkLite = m.contract('CrossChainArkLite', [arkParams, validationRegistry])

    return { crossChainArkLite }
  })
}

/**
 * Type definition for the returned contract address
 */
export type CrossChainArkLiteContracts = {
  crossChainArkLite: { address: string }
}
