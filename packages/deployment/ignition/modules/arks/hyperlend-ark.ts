import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a HyperlendArkModule for deploying the HyperlendArk contract
 *
 * This function creates a module that deploys the HyperlendArk contract, which integrates with the Hyperlend protocol.
 * Hyperlend is a fork of Aave V3 with some modifications, including Frax v3 isolated lending pools.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createHyperlendArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const hyperlendPool = m.getParameter('hyperlendPool')
    const rewardsController = m.getParameter('rewardsController')
    const arkParams = m.getParameter('arkParams')

    const hyperlendArk = m.contract('HyperlendArk', [hyperlendPool, rewardsController, arkParams])

    return { hyperlendArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type HyperlendArkContracts = {
  hyperlendArk: { address: string }
}
