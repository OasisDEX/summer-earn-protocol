import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * CompoundV3ArkModule for deploying the CompoundV3Ark contract
 *
 * This module deploys the CompoundV3Ark contract, which integrates with the Compound V3 protocol.
 *
 * @param {string} compoundV3Pool - The address of the Compound V3 pool (Comet)
 * @param {string} compoundV3Rewards - The address of the Compound V3 rewards controller
 * @param {object} arkParams - An object containing the parameters for the Ark contract
 *
 * @returns {CompoundV3ArkContracts} An object containing the address of the deployed CompoundV3Ark contract
 */
export default buildModule('CompoundV3ArkModule', (m) => {
  const compoundV3Pool = m.getParameter('compoundV3Pool')
  const compoundV3Rewards = m.getParameter('compoundV3Rewards')
  const arkParams = m.getParameter('arkParams')

  const compoundV3Ark = m.contract('CompoundV3Ark', [compoundV3Pool, compoundV3Rewards, arkParams])

  return { compoundV3Ark }
})

/**
 * Type definition for the returned contract address
 */
export type CompoundV3ArkContracts = {
  compoundV3Ark: { address: string }
}
