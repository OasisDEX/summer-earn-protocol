import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create an UpshiftArkModule for deploying the UpshiftArk contract
 *
 * This function creates a module that deploys the UpshiftArk contract, which integrates with an Upshift vault.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createUpshiftArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const vault = m.getParameter('vault')
    const arkParams = m.getParameter('arkParams')

    const upshiftArk = m.contract('UpshiftArk', [vault, arkParams])

    return { upshiftArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type UpshiftArkContracts = {
  upshiftArk: { address: string }
}
