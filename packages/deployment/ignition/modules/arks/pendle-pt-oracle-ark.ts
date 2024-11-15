import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a PendlePtOracleArkModule for deploying the PendlePtOracleArk contract
 *
 * This function creates a module that deploys the PendlePtOracleArk contract, which manages a Pendle Principal Token (PT) strategy.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createPendlePtOracleArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const market = m.getParameter('market')
    const oracle = m.getParameter('oracle')
    const router = m.getParameter('router')
    const marketAssetOracle = m.getParameter('marketAssetOracle')
    const arkParams = m.getParameter('arkParams')

    const pendleArkParams = {
      router: router,
      oracle: oracle,
      market: market,
    }

    const curveSwapArkParams = {
      curvePool: marketAssetOracle,
      basePrice: 10n ** 18n,
      lowerPercentageRange: 100n * 10n ** 18n,
      upperPercentageRange: 100n * 10n ** 18n,
    }

    const pendlePtOracleArk = m.contract('PendlePtOracleArk', [
      arkParams,
      pendleArkParams,
      curveSwapArkParams,
    ])

    return { pendlePtOracleArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type PendlePtOracleArkContracts = {
  pendlePtOracleArk: { address: string }
}
