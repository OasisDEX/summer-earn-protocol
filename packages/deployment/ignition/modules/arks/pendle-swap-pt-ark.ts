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
export default buildModule('PendleSwapPtModule', (m) => {
  const market = m.getParameter('market')
  const oracle = m.getParameter('oracle')
  const router = m.getParameter('router')
  const arkParams = m.getParameter('arkParams')

  const pendleArkParams = {
    router: router,
    oracle: oracle,
    market: market,
  }
  const curveSwapArkParams = {
    curvePool: '0x1c34204FCFE5314Dcf53BE2671C02c35DB58B4e3',
    marketAsset: '0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34',
  }

  const pendlePTArk = m.contract('CurveSwapPendlePtArk', [
    arkParams,
    pendleArkParams,
    curveSwapArkParams,
  ])

  return { pendlePTArk }
})

/**
 * Type definition for the returned contract address
 */
export type PendlePTArkContracts = {
  pendlePTArk: { address: string }
}
