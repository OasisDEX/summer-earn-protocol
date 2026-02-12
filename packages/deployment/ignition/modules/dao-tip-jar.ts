import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

/**
 * Type definition for the returned contract addresses
 */
export type DaoTipJarContracts = {
  daoTipJar: { address: Address }
}

/**
 * Factory function to create a DaoTipJarModule for deploying a TipJar dedicated to DAO fleets.
 *
 * @param {string} moduleName - Name of the module (use staging_DaoTipJar for bummer/staging, DaoTipJar for prod)
 * @returns {Function} A function that builds the module
 */
export function createDaoTipJarModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const accessManager = m.getParameter<string>('accessManager')
    const configurationManager = m.getParameter<string>('configurationManager')

    const daoTipJar = m.contract('TipJar', [accessManager, configurationManager])

    return { daoTipJar }
  })
}
