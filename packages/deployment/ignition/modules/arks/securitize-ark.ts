import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export function createSecuritizeArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const custodianWallet = m.getParameter<string>('targetWallet')
    const shareToken = m.getParameter<string>('shareToken')
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

    // Note: the registry service is resolved on-chain from the DSToken (getDSService(4)),
    // so it is intentionally NOT a constructor parameter.
    const ark = m.contract('SecuritizeArk', [
      custodianWallet,
      shareToken,
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
