import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export function createWisdomTreeArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const targetWallet = m.getParameter<string>('targetWallet')
    const name = m.getParameter<string>('name')
    const details = m.getParameter<string>('details')
    const configurationManager = m.getParameter<string>('configurationManager')
    const accessManager = m.getParameter<string>('accessManager')
    const asset = m.getParameter<string>('asset')
    const depositCap = m.getParameter<string>('depositCap')
    const maxRebalanceOutflow = m.getParameter<string>('maxRebalanceOutflow')
    const maxRebalanceInflow = m.getParameter<string>('maxRebalanceInflow')
    const requiresKeeperData = m.getParameter<boolean>('requiresKeeperData')
    const maxDepositPercentageOfTVL = m.getParameter<string>('maxDepositPercentageOfTVL')

    const ark = m.contract('WisdomTreeArk', [
      targetWallet,
      {
        name,
        details,
        configurationManager,
        accessManager,
        asset,
        depositCap,
        maxRebalanceOutflow,
        maxRebalanceInflow,
        requiresKeeperData,
        maxDepositPercentageOfTVL,
      },
    ])

    return { ark }
  })
}
