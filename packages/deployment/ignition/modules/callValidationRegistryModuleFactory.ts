import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a CallValidationRegistryModule for deploying the CallValidationRegistry contract
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createCallValidationRegistryModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const accessManager = m.getParameter('accessManager')

    const callValidationRegistry = m.contract('CallValidationRegistry', [accessManager])

    return { callValidationRegistry }
  })
}

// Legacy-style export for convenience
export const CallValidationRegistryModule = createCallValidationRegistryModule(
  'CallValidationRegistryModule',
)

/**
 * Type definition for the returned contract address
 */
export type CallValidationRegistryContract = {
  callValidationRegistry: { address: string }
}
