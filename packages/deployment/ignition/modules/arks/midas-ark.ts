import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a MidasArkModule for deploying the MidasArk contract
 *
 * This function creates a module that deploys the MidasArk contract, which integrates with the Midas protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createMidasArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const issuanceVault = m.getParameter('issuanceVault')
    const redemptionVault = m.getParameter('redemptionVault')
    const arkParams = m.getParameter('arkParams')

    const midasArk = m.contract('MidasArk', [issuanceVault, redemptionVault, arkParams])

    return { midasArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type MidasArkContracts = {
  midasArk: { address: string }
}
