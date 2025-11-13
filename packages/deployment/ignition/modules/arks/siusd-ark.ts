import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SiUSDArkModule for deploying the SiUSDArk contract
 *
 * This function creates a module that deploys the SiUSDArk contract, which integrates with InfiniFi's siUSD vault.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSiUSDArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const gateway = m.getParameter('gateway')
    const siUSD = m.getParameter('siUSD')
    const arkParams = m.getParameter('arkParams')

    const siUSDArk = m.contract('SiUSDArk', [gateway, siUSD, arkParams])

    return { siUSDArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type SiUSDArkContracts = {
  siUSDArk: { address: string }
}
