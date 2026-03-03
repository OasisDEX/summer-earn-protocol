import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a MorphoV2VaultArkModule for deploying the MorphoV2VaultArk contract
 *
 * This function creates a module that deploys the MorphoV2VaultArk contract, which integrates with
 * MetaMorpho (Morpho V2) vaults. Uses previewRedeem instead of maxWithdraw for withdrawable assets.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createMorphoV2VaultArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const vault = m.getParameter('vault')
    const arkParams = m.getParameter('arkParams')

    const morphoV2VaultArk = m.contract('MorphoV2VaultArk', [vault, arkParams])

    return { morphoV2VaultArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type MorphoV2VaultArkContracts = {
  morphoV2VaultArk: { address: string }
}
