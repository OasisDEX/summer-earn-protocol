import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a MetaMorphoArkModule for deploying the MetaMorphoArk contract
 *
 * This function creates a module that deploys the MetaMorphoArk contract, which integrates with the MetaMorpho protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createMetaMorphoArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const strategyVault = m.getParameter('strategyVault')
    const arkParams = m.getParameter('arkParams')

    const metaMorphoArk = m.contract('MetaMorphoArk', [strategyVault, arkParams])

    return { metaMorphoArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type MetaMorphoArkContracts = {
  metaMorphoArk: { address: string }
}
