import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a MoonwellArkModule for deploying the MoonwellArk contract
 *
 * This function creates a module that deploys the MoonwellArk contract, which integrates with the Moonwell protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createMoonwellArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const mToken = m.getParameter('mToken')
    const arkParams = m.getParameter('arkParams')

    const moonwellArk = m.contract('MoonwellArk', [mToken, arkParams])

    return { moonwellArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type MoonwellArkContracts = {
  moonwellArk: { address: string }
}
