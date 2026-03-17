import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a MapleInstitutionalArkModule for deploying the MapleInstitutionalArk contract
 *
 * This function creates a module that deploys the MapleInstitutionalArk contract, which integrates with Maple Institutional pools.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createMapleInstitutionalArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const vault = m.getParameter('vault')
    const arkParams = m.getParameter('arkParams')

    const mapleInstitutionalArk = m.contract(`MapleInstitutionalArk`, [vault, arkParams])

    return { mapleInstitutionalArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type MapleInstitutionalArkContracts = {
  mapleInstitutionalArk: { address: string }
}
