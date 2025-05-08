import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create an AdmiralsQuartersModule for deploying the AdmiralsQuarters contract
 *
 * This function creates a module that deploys the AdmiralsQuarters contract.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createAdmiralsQuartersModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const swapProvider = m.getParameter('swapProvider')
    const configurationManager = m.getParameter('configurationManager')
    const weth = m.getParameter('weth')

    const admiralsQuarters = m.contract('AdmiralsQuarters', [
      swapProvider,
      configurationManager,
      weth,
    ])

    return { admiralsQuarters }
  })
}

// Legacy export for backward compatibility
export const AdmiralsQuartersModule = createAdmiralsQuartersModule('AdmiralsQuartersModule')

/**
 * Type definition for the returned contract address
 */
export type AdmiralsQuartersContract = {
  admiralsQuarters: { address: string }
}
