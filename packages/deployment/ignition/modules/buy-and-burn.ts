import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

enum DecayType {
  Linear,
  Exponential,
}

export const BuyAndBurnModule = buildModule('BuyAndBurnModule', (m) => {
  const summerToken = m.getParameter('summerToken')
  const protocolAccessManager = m.getParameter('protocolAccessManager')
  const configurationManager = m.getParameter('configurationManager')
  const auctionDefaultParams = {
    duration: 7n * 86400n,
    startPrice: 100n ** 18n,
    endPrice: 10n ** 18n,
    kickerRewardPercentage: 5n * 10n ** 18n,
    decayType: DecayType.Linear,
  }

  // Deploy DutchAuctionLibrary contract
  const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])

  // Deploy BuyAndBurn contract with DutchAuctionLibrary as a library
  const buyAndBurn = m.contract(
    'BuyAndBurn',
    [summerToken, protocolAccessManager, configurationManager, auctionDefaultParams],
    {
      libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
    },
  )

  return {
    buyAndBurn,
  }
})

export type BuyAndBurnContracts = {
  buyAndBurn: { address: string }
}
