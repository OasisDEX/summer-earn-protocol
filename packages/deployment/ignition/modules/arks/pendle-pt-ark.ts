import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a PendlePTArkModule for deploying the PendlePTArk contract
 *
 * This function creates a module that deploys the PendlePTArk contract, which manages a Pendle Principal Token (PT) strategy.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createPendlePTArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const market = m.getParameter('market')
    const oracle = m.getParameter('oracle')
    const router = m.getParameter('router')
    const arkParams = m.getParameter('arkParams')

    const pendlePTArk = m.contract('PendlePTArk', [market, oracle, router, arkParams])

    return { pendlePTArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type PendlePTArkContracts = {
  pendlePTArk: { address: string }
}
