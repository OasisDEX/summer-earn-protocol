import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export type SuperstateArkVariant = 'standard' | 'subscribe'

/**
 * Builds a Superstate ark deployment module.
 *
 * There is no single `SuperstateArk` contract — the protocol ships two concrete arks with different
 * constructors, so `variant` (a build-time JS value, NOT an Ignition parameter — it drives control
 * flow) selects which one to deploy:
 *
 *  - 'subscribe' → `SuperstateSubscribeArk(shareToken, superstateSubscribe, superstateRedeem,
 *                   oracle, sweepSlippage, depositSlippage, ArkParams)` — USTB-style: subscriptions
 *                   via SUPERSTATE_SUBSCRIBE plus an on-chain RedemptionIdle contract.
 *  - 'standard' → `SuperstateStandardArk(shareToken, depositAddress, oracle, sweepSlippage,
 *                   depositSlippage, ArkParams)` — USCC-style: deposit straight to the fund token,
 *                   off-chain redemption (no redeem contract). `superstateSubscribe` carries the
 *                   deposit address here.
 */
export function createSuperstateArkModule(moduleName: string, variant: SuperstateArkVariant) {
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

    const arkParams = {
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
    }

    if (variant === 'subscribe') {
      const superstateRedeem = m.getParameter<string>('superstateRedeem')
      const ark = m.contract('SuperstateSubscribeArk', [
        shareToken,
        superstateSubscribe,
        superstateRedeem,
        oracle,
        sweepSlippage,
        depositSlippage,
        arkParams,
      ])
      return { ark }
    }

    const ark = m.contract('SuperstateStandardArk', [
      shareToken,
      superstateSubscribe, // == depositAddress for the standard ark
      oracle,
      sweepSlippage,
      depositSlippage,
      arkParams,
    ])
    return { ark }
  })
}
