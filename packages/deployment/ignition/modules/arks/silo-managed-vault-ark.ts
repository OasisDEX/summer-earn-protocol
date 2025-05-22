import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SiloManagedVaultArkModule for deploying the SiloManagedVaultArk contract
 *
 * This function creates a module that deploys the SiloManagedVaultArk contract, which integrates with Silo managed vaults.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSiloManagedVaultArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const vault = m.getParameter('vault')
    const arkParams = m.getParameter('arkParams')

    const siloManagedVaultArk = m.contract('SiloManagedVaultArk', [vault, arkParams])

    return { siloManagedVaultArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type SiloManagedVaultArkContracts = {
  siloManagedVaultArk: { address: string }
}
