import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * PendlePTArkModule for deploying the PendlePTArk contract
 *
 * This module deploys the PendlePTArk contract, which manages a Pendle Principal Token (PT) strategy within the Ark system.
 *
 * @param {string} market - The address of the Pendle market
 * @param {string} oracle - The address of the Pendle oracle
 * @param {string} router - The address of the Pendle router
 * @param {object} arkParams - An object containing the parameters for the Ark contract
 *
 * @returns {PendlePTArkContracts} An object containing the address of the deployed PendlePTArk contract
 */
export default buildModule('PendlePTArkModule', (m) => {
  const market = m.getParameter('market')
  const oracle = m.getParameter('oracle')
  const router = m.getParameter('router')
  const arkParams = m.getParameter('arkParams')

  const pendlePTArk = m.contract('PendlePTArk', [market, oracle, router, arkParams])

  return { pendlePTArk }
})

/**
 * Type definition for the returned contract address
 */
export type PendlePTArkContracts = {
  pendlePTArk: { address: string }
}
