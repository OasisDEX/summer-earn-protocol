import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a CompoundV3ArkModule for deploying the CompoundV3Ark contract
 *
 * This function creates a module that deploys the CompoundV3Ark contract, which integrates with the Compound V3 protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createCompoundV3ArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const compoundV3Pool = m.getParameter('compoundV3Pool')
    const compoundV3Rewards = m.getParameter('compoundV3Rewards')
    const arkParams = m.getParameter('arkParams')

    const compoundV3Ark = m.contract('CompoundV3Ark', [
      compoundV3Pool,
      compoundV3Rewards,
      arkParams,
    ])

    return { compoundV3Ark }
  })
}

/**
 * Type definition for the returned contract address
 */
export type CompoundV3ArkContracts = {
  compoundV3Ark: { address: string }
}
