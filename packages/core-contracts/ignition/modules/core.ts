import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('Core', (m) => {
  // Addresses
  const deployer = m.getAccount(0)
  const swapProvider = m.getParameter('swapProvider')
  const treasury = m.getParameter('treasury')

  const protocolAccessManager = m.contract('ProtocolAccessManager', [deployer])
  const tipJar = m.contract('TipJar', [protocolAccessManager, treasury])
  const raft = m.contract('Raft', [swapProvider, protocolAccessManager])
  const configurationManager = m.contract('ConfigurationManager', [
    { accessManager: protocolAccessManager, raft, tipJar },
  ])
  const harborCommander = m.contract('HarborCommand', [protocolAccessManager])

  return { protocolAccessManager, tipJar, raft, configurationManager }
})

export type CoreContracts = {
  protocolAccessManager: { address: string }
  tipJar: { address: string }
  raft: { address: string }
  configurationManager: { address: string }
}
