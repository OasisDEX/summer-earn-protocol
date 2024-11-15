import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a PendleLPArkModule for deploying the PendleLPArk contract
 *
 * This function creates a module that deploys the PendleLPArk contract, which manages a Pendle LP token strategy.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createPendleLPArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const market = m.getParameter('market')
    const oracle = m.getParameter('oracle')
    const router = m.getParameter('router')
    const arkParams = m.getParameter('arkParams')

    const pendleLPArk = m.contract('PendleLPArk', [market, oracle, router, arkParams])

    return { pendleLPArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type PendleLPArkContracts = {
  pendleLPArk: { address: string }
}
