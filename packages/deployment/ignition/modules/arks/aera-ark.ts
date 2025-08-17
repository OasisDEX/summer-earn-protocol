import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SiloArkModule for deploying the SiloArk contract
 *
 * This function creates a module that deploys the SiloArk contract, which integrates with Silo vaults.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createAeraArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const provisioner = m.getParameter('provisioner')
    const arkParams = m.getParameter('arkParams')

    const aeraArk = m.contract('AeraArk', [provisioner, arkParams])

    return { aeraArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type AeraArkContracts = {
  aeraArk: { address: string }
}
