import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export function createRoundsVaultInputModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const targetVault = m.getParameter<string>('targetVault')
    const accessManager = m.getParameter<string>('accessManager')
    const receiptsURI = m.getParameter<string>('receiptsURI')

    const roundsVaultInput = m.contract('RoundsVaultInput', [
      targetVault,
      accessManager,
      receiptsURI,
    ])

    return { roundsVaultInput }
  })
}

export function createRoundsVaultOutputModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const targetVault = m.getParameter<string>('targetVault')
    const accessManager = m.getParameter<string>('accessManager')
    const receiptsURI = m.getParameter<string>('receiptsURI')

    const roundsVaultOutput = m.contract('RoundsVaultOutput', [
      targetVault,
      accessManager,
      receiptsURI,
    ])

    return { roundsVaultOutput }
  })
}
