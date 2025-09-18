import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SummerOracleFactoryModule for deploying the SummerOracleFactory contract
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSummerOracleFactoryModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const harborCommand = m.getParameter('harborCommand')

    const summerOracleFactory = m.contract('SummerOracleFactory', [harborCommand])

    return { summerOracleFactory }
  })
}

// Legacy export for convenience
export const SummerOracleFactoryModule = createSummerOracleFactoryModule(
  'SummerOracleFactoryModule',
)

export type SummerOracleFactoryContracts = {
  summerOracleFactory: { address: string }
}
