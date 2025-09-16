import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SiloArkV2Module for deploying the SiloArkV2 contract
 *
 * This function creates a module that deploys the SiloArkV2 contract, which integrates with Silo vaults.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSiloArkV2Module(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const silo = m.getParameter('silo')
    const arkParams = m.getParameter('arkParams')

    const siloArkV2 = m.contract('SiloVaultArkV2', [silo, arkParams])

    return { siloArkV2 }
  })
}

/**
 * Type definition for the returned contract address
 */
export type SiloArkV2Contracts = {
  siloArkV2: { address: string }
}
