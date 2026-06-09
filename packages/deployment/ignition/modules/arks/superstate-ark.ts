import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export function createSuperstateArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const shareToken = m.getParameter<string>('shareToken')
    const superstateSubscribe = m.getParameter<string>('superstateSubscribe')
    const oracle = m.getParameter<string>('oracle')
    const sweepSlippage = m.getParameter<string>('sweepSlippage')
    const depositSlippage = m.getParameter<string>('depositSlippage')
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

    const ark = m.contract('SuperstateArk', [
      shareToken,
      superstateSubscribe,
      oracle,
      sweepSlippage,
      depositSlippage,
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
