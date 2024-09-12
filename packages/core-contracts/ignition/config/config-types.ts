export interface BaseConfig {
  tokens: {
    usdc: string
    dai: string
    usdt: string
  }
  core: {
    treasury: string
    governor: string
    tipJar: string
    swapProvider: string
    raft: string
    protocolAccessManager: string
    configurationManager: string
    harborCommand: string
    tipRate: string
  }
  aaveV3: {
    pool: string
    rewards: string
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
  compoundV3: {
    pools: {
      usdc: { cToken: string }
      usdt: { cToken: string }
    }
    rewards: string
  }
}

export interface Config {
  mainnet: any
  base: BaseConfig
}
