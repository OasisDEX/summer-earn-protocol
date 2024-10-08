import { BuyAndBurnContracts } from '../ignition/modules/buy-and-burn'
import { CoreContracts } from '../ignition/modules/core'
import { GovContracts } from '../ignition/modules/gov'

export enum Tokens {
  USDC = 'usdc',
  DAI = 'dai',
  USDT = 'usdt',
  USDE = 'usde',
}
export type TokenType = Tokens.DAI | Tokens.USDC | Tokens.USDT | Tokens.USDE

export interface BaseConfig {
  deployedContracts: {
    core: CoreContracts
    gov: GovContracts
    buyAndBurn: BuyAndBurnContracts
  }
  common: {
    treasury: string
    lzEndpoint: string
    swapProvider: string
    tipRate: string
  }
  tokens: {
    [key in Tokens]: string
  }
  protocolSpecific: {
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
}
export interface FleetConfig {
  fleetName: string
  symbol: string
  assetSymbol: string
  initialMinimumBufferBalance: string
  initialRebalanceCooldown: string
  depositCap: string
  initialTipRate: string
  network: string
}

export interface Config {
  mainnet: BaseConfig
  base: BaseConfig
  arbitrum: BaseConfig
}
