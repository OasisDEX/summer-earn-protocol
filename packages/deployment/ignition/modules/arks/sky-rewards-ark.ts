import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SkyRewardsArkModule for deploying the SkyRewardsArk contract
 *
 * This function creates a module that deploys the SkyRewardsArk contract, which integrates with the Sky protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSkyRewardsArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const litePsm = m.getParameter('litePsm')
    const usds = m.getParameter('usds')
    const stakingRewards = m.getParameter('stakingRewards')
    const arkParams = m.getParameter('arkParams')

    const skyRewardsArk = m.contract('SkyRewardsArk', [litePsm, usds, stakingRewards, arkParams])

    return { skyRewardsArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type SkyRewardsArkContracts = {
  skyRewardsArk: { address: string }
}
