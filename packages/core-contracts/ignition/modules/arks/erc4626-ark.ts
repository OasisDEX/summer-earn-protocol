import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create an ERC4626ArkModule for deploying the ERC4626Ark contract
 *
 * This function creates a module that deploys the ERC4626Ark contract, which integrates with any ERC4626-compliant vault.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createERC4626ArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const vault = m.getParameter('vault')
    const arkParams = m.getParameter('arkParams')

    const erc4626Ark = m.contract('ERC4626Ark', [vault, arkParams])

    return { erc4626Ark }
  })
}

/**
 * Type definition for the returned contract address
 */
export type ERC4626ArkContracts = {
  erc4626Ark: { address: string }
}
