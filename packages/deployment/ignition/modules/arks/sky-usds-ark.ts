import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a SkyUsdsArkModule for deploying the SkyUsdsArk contract
 *
 * This function creates a module that deploys the SkyUsdsArk contract, which integrates with the Sky protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createSkyUsdsArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const litePsm = m.getParameter('litePsm')
    const usds = m.getParameter('usds')
    const stakedUsds = m.getParameter('stakedUsds')
    const arkParams = m.getParameter('arkParams')

    const skyUsdsArk = m.contract('SkyUsdsArk', [litePsm, usds, stakedUsds, arkParams])

    return { skyUsdsArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type SkyUsdsArkContracts = {
  skyUsdsArk: { address: string }
}
