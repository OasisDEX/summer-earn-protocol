import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SummerVestingFactoryV2Module for deploying the SummerVestingFactoryV2 contract
 *
 * This function creates a module that deploys the SummerVestingFactoryV2 contract.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSummerVestingFactoryV2Module(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const token = m.getParameter('token')
    const owner = m.getParameter('owner')

    const summerVestingFactoryV2 = m.contract('SummerVestingWalletFactoryV2', [token, owner])

    return { summerVestingFactoryV2 }
  })
}

// Legacy export for backward compatibility
export const SummerVestingFactoryV2Module = createSummerVestingFactoryV2Module(
  'SummerVestingFactoryV2Module',
)

/**
 * Type definition for the returned contract address
 */
export type SummerVestingFactoryV2Contract = {
  summerVestingFactoryV2: { address: string }
}
