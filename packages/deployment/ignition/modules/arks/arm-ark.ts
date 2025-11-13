import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create an ArmArkModule for deploying the ArmArk contract
 *
 * This function creates a module that deploys the ArmArk contract, which integrates with the Origin ARM protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createArmArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const arm = m.getParameter('arm')
    const arkParams = m.getParameter('arkParams')

    const armArk = m.contract('ArmArk', [arm, arkParams])

    return { armArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type ArmArkContracts = {
  armArk: { address: string }
}
