import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * AaveV3ArkModule for deploying the AaveV3Ark contract
 *
 * This module deploys the AaveV3Ark contract, which integrates with the Aave V3 protocol.
 *
 * @param {string} aaveV3Pool - The address of the Aave V3 lending pool
 * @param {string} rewardsController - The address of the Aave V3 rewards controller
 * @param {object} arkParams - An object containing the parameters for the Ark contract
 *
 * @returns {AaveV3ArkContracts} An object containing the address of the deployed AaveV3Ark contract
 */
export default buildModule('AaveV3ArkModule', (m) => {
  const aaveV3Pool = m.getParameter('aaveV3Pool')
  const rewardsController = m.getParameter('rewardsController')
  const arkParams = m.getParameter('arkParams')

  const aaveV3Ark = m.contract('AaveV3Ark', [aaveV3Pool, rewardsController, arkParams])

  return { aaveV3Ark }
})

/**
 * Type definition for the returned contract address
 */
export type AaveV3ArkContracts = {
  aaveV3Ark: { address: string }
}
