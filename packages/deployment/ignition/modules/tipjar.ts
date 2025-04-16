import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

/**
 * Type definition for the returned contract address
 */
export type TipJarContracts = {
  tipJar: { address: Address }
}

/**
 * Creates a TipJar module for deployment
 *
 * @returns The TipJar module
 */
export function createTipJarModule() {
  return buildModule('TipJarModule', (m) => {
    const accessManager = m.getParameter<Address>('accessManager')
    const configurationManager = m.getParameter<Address>('configurationManager')

    const tipJar = m.contract('TipJar', [accessManager, configurationManager])

    return { tipJar }
  })
}
