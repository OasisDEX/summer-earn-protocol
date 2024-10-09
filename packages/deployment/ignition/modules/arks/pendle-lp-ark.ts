import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * PendleLPArkModule for deploying the PendleLPArk contract
 *
 * This module deploys the PendleLPArk contract, which manages a Pendle LP token strategy within the Ark system.
 *
 * @param {string} market - The address of the Pendle market
 * @param {string} oracle - The address of the Pendle oracle
 * @param {string} router - The address of the Pendle router
 * @param {object} arkParams - An object containing the parameters for the Ark contract
 *
 * @returns {PendleLPArkContracts} An object containing the address of the deployed PendleLPArk contract
 */
export default buildModule('PendleLPArkModule', (m) => {
  const market = m.getParameter('market')
  const oracle = m.getParameter('oracle')
  const router = m.getParameter('router')
  const arkParams = m.getParameter('arkParams')

  const pendleLPArk = m.contract('PendleLPArk', [market, oracle, router, arkParams])

  return { pendleLPArk }
})

/**
 * Type definition for the returned contract address
 */
export type PendleLPArkContracts = {
  pendleLPArk: { address: string }
}
