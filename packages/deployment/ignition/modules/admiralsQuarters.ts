import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export const AdmiralsQuartersModule = buildModule('AdmiralsQuartersModule', (m) => {
  const swapProvider = m.getParameter('swapProvider')
  const configurationManager = m.getParameter('configurationManager')
  const weth = m.getParameter('weth')

  const admiralsQuarters = m.contract('AdmiralsQuarters', [
    swapProvider,
    configurationManager,
    weth,
  ])

  return { admiralsQuarters }
})

export type AdmiralsQuartersContract = {
  admiralsQuarters: { address: string }
}
