import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Core Module for deploying the main contracts of the protocol
 *
 * This module deploys the following contracts:
 * - ProtocolAccessManager
 * - TipJar
 * - Raft
 * - ConfigurationManager
 * - HarborCommander
 *
 * @param {string} swapProvider - The address of the swap provider (e.g., Uniswap router)
 * @param {string} treasury - The address of the protocol treasury
 *
 * @returns {CoreContracts} An object containing the addresses of deployed contracts
 */
export default buildModule('CoreModule', (m) => {
  // Get the deployer account (first account in the list)
  const deployer = m.getAccount(0)

  // Get module parameters
  const swapProvider = m.getParameter('swapProvider')
  const treasury = m.getParameter('treasury')

  // Deploy ProtocolAccessManager
  const protocolAccessManager = m.contract('ProtocolAccessManager', [deployer])

  // Deploy TipJar
  const tipJar = m.contract('TipJar', [protocolAccessManager, treasury])

  // Deploy Raft
  const raft = m.contract('Raft', [swapProvider, protocolAccessManager])

  // Deploy ConfigurationManager
  const configurationManager = m.contract('ConfigurationManager', [
    { accessManager: protocolAccessManager, raft, tipJar },
  ])

  // Deploy HarborCommander
  const harborCommander = m.contract('HarborCommand', [protocolAccessManager])

  // Return the deployed contract instances
  return { protocolAccessManager, tipJar, raft, configurationManager, harborCommander }
})

/**
 * Type definition for the returned contract addresses
 */
export type CoreContracts = {
  protocolAccessManager: { address: string }
  tipJar: { address: string }
  raft: { address: string }
  configurationManager: { address: string }
  harborCommander: { address: string }
}
