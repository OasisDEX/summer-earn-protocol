export interface BaseConfig {
  tokens: {
    usdc: string
    dai: string
  }
  treasury: string
  governor: string
  tipJar: string
  swapProvider: string
  aaveV3: {
    pool: string
    rewards: string
  }
  compound: {
    usdc: {
      pool: string
      rewards: string
    }
  }
  morpho: {
    blue: string
    usdc: {
      marketId: string
    }
    dai: {
      marketId: string
    }
  }
  metaMorpho: {
    steakhouseUsdc: string
  }
  raft: string
  protocolAccessManager: string
  configurationManager: string
  usdcFleetCommander_test: string
  daiFleetCommander_test: string
  harborCommand: string
  bufferArk: {
    usdc: string
    dai: string
  }
  usdcAaveV3Ark: string
  daiAaveV3Ark: string
  usdcCompoundV3Ark: string
  metamorphoSteakhouseUsdcArk: string
  usdcMorphoArk: string
  daiMorphoArk: string
  tipRate: string
}

export interface Config {
  mainnet: any
  base: BaseConfig
}
