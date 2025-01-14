import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a MorphoArkModule for deploying the MorphoArk contract
 *
 * This function creates a module that deploys the MorphoArk contract, which integrates with the Morpho protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createMorphoArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const morphoBlue = m.getParameter('morphoBlue')
    const marketId = m.getParameter('marketId')
    const urdFactory = m.getParameter('urdFactory')
    const arkParams = m.getParameter('arkParams')

    const morphoArk = m.contract('MorphoArk', [morphoBlue, marketId, urdFactory, arkParams])

    return { morphoArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type MorphoArkContracts = {
  morphoArk: { address: string }
}
