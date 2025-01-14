import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a MorphoVaultArkModule for deploying the MorphoVaultArk contract
 *
 * This function creates a module that deploys the MorphoVaultArk contract, which integrates with the Morpho protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createMorphoVaultArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const strategyVault = m.getParameter('strategyVault')
    const urdFactory = m.getParameter('urdFactory')
    const arkParams = m.getParameter('arkParams')

    const morphoVaultArk = m.contract('MorphoVaultArk', [strategyVault, urdFactory, arkParams])

    return { morphoVaultArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type MorphoVaultArkContracts = {
  morphoVaultArk: { address: string }
}
