import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a MorphoVaultV2ArkModule for deploying the MorphoVaultV2Ark contract
 *
 * This function creates a module that deploys the MorphoVaultV2Ark contract.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createMorphoVaultV2ArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const vault = m.getParameter('vault')
    const arkParams = m.getParameter('arkParams')

    const morphoVaultV2Ark = m.contract('MorphoVaultV2Ark', [vault, arkParams])

    return { morphoVaultV2Ark }
  })
}

/**
 * Type definition for the returned contract address
 */
export type MorphoVaultV2ArkContracts = {
  morphoVaultV2Ark: { address: string }
}
