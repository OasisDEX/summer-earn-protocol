export enum Tokens {
  USDC = 'usdc',
  DAI = 'dai',
  USDT = 'usdt',
  USDE = 'usde',
}
export type TokenType = Tokens.DAI | Tokens.USDC | Tokens.USDT | Tokens.USDE

export interface BaseConfig {
  tokens: {
    [key in Tokens]: string
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
  erc4626: {
    [key in Tokens]: {
      [key: string]: string
    }
  }
  pendle: {
    router: string
    'lp-oracle': string
    markets: {
      [key in Tokens]: {
        [key: string]: string
      }
    }
  }
  aaveV3: {
    pool: string
    rewards: string
  }
  morpho: {
    blue: string
    vaults: {
      [key in Tokens]: {
        [key: string]: string
      }
    }
    markets: {
      [key in Tokens]: {
        [key: string]: string
      }
    }
  }
  compoundV3: {
    pools: {
      [key in Tokens]: {
        cToken: string
      }
    }
    rewards: string
  }
}

export interface Config {
  mainnet: any
  base: BaseConfig
  arbitrum: BaseConfig
}
