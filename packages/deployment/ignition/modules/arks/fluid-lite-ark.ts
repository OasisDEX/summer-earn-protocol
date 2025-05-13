import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a FluidLiteArkModule for deploying the FluidLiteArk contract
 *
 * This function creates a module that deploys the FluidLiteArk contract, which integrates with the FluidLite protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createFluidLiteArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const wrapper = m.getParameter('wrapper')
    const vault = m.getParameter('vault')
    const weth = m.getParameter('weth')
    const steth = m.getParameter('steth')
    const withdrawalQueue = m.getParameter('withdrawalQueue')
    const arkParams = m.getParameter('arkParams')

    const fluidLiteArk = m.contract('FluidLiteArk', [
      wrapper,
      vault,
      weth,
      steth,
      withdrawalQueue,
      arkParams,
    ])

    return { fluidLiteArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type FluidLiteArkContracts = {
  fluidLiteArk: { address: string }
}
