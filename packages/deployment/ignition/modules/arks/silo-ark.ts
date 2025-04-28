import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SiloArkModule for deploying the SiloArk contract
 *
 * This function creates a module that deploys the SiloArk contract, which integrates with Silo vaults.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSiloArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const silo = m.getParameter('silo')
    const arkParams = m.getParameter('arkParams')

    const siloArk = m.contract('SiloVaultArk', [silo, arkParams])

    return { siloArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type SiloArkContracts = {
  siloArk: { address: string }
}
