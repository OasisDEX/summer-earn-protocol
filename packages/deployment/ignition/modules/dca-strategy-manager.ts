import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a DCAStrategyManagerModule for deploying the DCAStrategyManager contract.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createDCAStrategyManagerModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const protocolAccessManager = m.getParameter('protocolAccessManager')
    const ensoRouter = m.getParameter('ensoRouter')
    const harborCommand = m.getParameter('harborCommand')
    const permit2 = m.getParameter('permit2')

    const dcaStrategyManager = m.contract('DCAStrategyManager', [
      protocolAccessManager,
      ensoRouter,
      harborCommand,
      permit2,
    ])

    return { dcaStrategyManager }
  })
}

// Legacy export for backward compatibility
export const DCAStrategyManagerModule = createDCAStrategyManagerModule('DCAStrategyManagerModule')

/**
 * Type definition for the returned contract address
 */
export type DCAStrategyManagerContracts = {
  dcaStrategyManager: { address: string }
}
