import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a HypurrArkModule for deploying the HypurrfiArk contract
 *
 * This function creates a module that deploys the HypurrfiArk contract, which integrates with the Hypurrfi protocol.
 * Hypurrfi is a fork of Aave V3 with some modifications, including Frax v3 isolated lending pools.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createHypurrArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const hypurrPool = m.getParameter('hypurrPool')
    const rewardsController = m.getParameter('rewardsController')
    const arkParams = m.getParameter('arkParams')

    const hypurrArk = m.contract('HypurrfiArk', [hypurrPool, rewardsController, arkParams])

    return { hypurrArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type HypurrArkContracts = {
  hypurrArk: { address: string }
}
