import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a Psm3ERC4626ArkModule for deploying the Psm3ERC4626Ark contract
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createPsm3ERC4626ArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const psm = m.getParameter('psm')
    const usds = m.getParameter('usds')
    const stakedUsds = m.getParameter('stakedUsds')
    const vault = m.getParameter('vault')
    const arkParams = m.getParameter('arkParams')

    const ark = m.contract('Psm3ERC4626Ark', [psm, usds, stakedUsds, vault, arkParams])

    return { ark }
  })
}
