import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * PendlePTArkModule for deploying the PendlePTArk contract
 *
 * This module deploys the PendlePTArk contract, which manages a Pendle Principal Token (PT) strategy within the Ark system.
 *
 * @param market - The address of the Pendle market
 * @param oracle - The address of the Pendle oracle
 * @param router - The address of the Pendle router
 * @param arkParams - An object containing the parameters for the Ark contract
 *
 * @returns  An object containing the address of the deployed PendlePTArk contract
 */
export default buildModule('PendlePtOracleArkModule', (m) => {
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
    basePrice: 1e18,
    lowerPercentageRange: 100 * 1e18,
    upperPercentageRange: 100 * 1e18,
  }

  const pendlePtOracleArk = m.contract('PendlePtOracleArk', [
    arkParams,
    pendleArkParams,
    curveSwapArkParams,
  ])

  return { pendlePtOracleArk }
})

/**
 * Type definition for the returned contract address
 */
export type PendlePtOracleArkContracts = {
  pendlePtOracleArk: { address: string }
}
