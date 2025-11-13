import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a FluidFTokenArkModule for deploying the FluidFTokenArk contract
 *
 * This function creates a module that deploys the FluidFTokenArk contract, which integrates with
 * a Fluid fToken ERC4626-compliant vault and supports Fluid Merkle reward harvesting via claim data.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createFluidFTokenArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const vault = m.getParameter('vault')
    const arkParams = m.getParameter('arkParams')

    const fluidFTokenArk = m.contract('FluidFTokenArk', [vault, arkParams])

    return { fluidFTokenArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type FluidFTokenArkContracts = {
  fluidFTokenArk: { address: string }
}
