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
 * @param {Object} params Parameters for the TipJar
 * @param {Address} params.token The token that will be used for tips
 * @returns The TipJar module
 */
export function createTipJarModule(params: { token: Address }) {
  return buildModule('TipJarModule', (m) => {
    const token = params.token

    const tipJar = m.contract('TipJar', [token])

    return { tipJar }
  })
}
