import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a HyperBeatCoreArkModule for deploying the HyperBeatCoreArk contract
 *
 * This function creates a module that deploys the HyperBeatCoreArk contract, which integrates with the HyperBeatCore protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createHyperBeatCoreArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const depositor = m.getParameter('depositor')
    const withdrawalQueue = m.getParameter('withdrawalQueue')
    const arkParams = m.getParameter('arkParams')

    const hyperBeatCoreArk = m.contract('HyperBeatCoreArk', [depositor, withdrawalQueue, arkParams])

    return { hyperBeatCoreArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type HyperBeatCoreArkContracts = {
  hyperBeatCoreArk: { address: string }
}
