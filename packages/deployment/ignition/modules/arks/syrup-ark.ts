import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SyrupArkModule for deploying the SyrupArk contract
 *
 * This function creates a module that deploys the SyrupArk contract, which integrates with any Syrup-compliant vault.
 *
 * @param {string} moduleName - Name of the module
 * @param {number} version - Version of the SyrupArk contract
 * @returns {Function} A function that builds the module
 */
export function createSyrupArkModule(moduleName: string, version: number) {
  return buildModule(moduleName, (m) => {
    const vault = m.getParameter('vault')
    const router = m.getParameter('router')
    const arkParams = m.getParameter('arkParams')
    const versionString = version == 1 ? 'SyrupArk' : `SyrupArkV${version}`
    const syrupArk = m.contract(versionString, [vault, router, arkParams])

    return { syrupArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type SyrupArkContracts = {
  syrupArk: { address: string }
}
