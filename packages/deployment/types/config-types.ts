import { Address } from 'viem'
import { BuyAndBurnContracts } from '../ignition/modules/buy-and-burn'
import { CoreContracts } from '../ignition/modules/core'
import { GovContracts } from '../ignition/modules/gov'

export enum Tokens {
  USDC = 'usdc',
  DAI = 'dai',
  USDT = 'usdt',
  USDE = 'usde',
  USDCE = 'usdce',
}
export type TokenType = Tokens.DAI | Tokens.USDC | Tokens.USDT | Tokens.USDE | Tokens.USDCE

export interface BaseConfig {
  deployedContracts: {
    core: CoreContracts
    gov: GovContracts
    buyAndBurn: BuyAndBurnContracts
  }
  common: {
    treasury: Address
    lzEndpoint: Address
    swapProvider: Address
    tipRate: string
  }
  tokens: {
    [key in Tokens]: Address
  }
  protocolSpecific: {
    erc4626: {
      [key in Tokens]: {
        [key: string]: Address
      }
    }
    pendle: {
      router: Address
      'lp-oracle': Address
      markets: {
        [key in Tokens]: {
          swapInTokens: Array<{
            token: TokenType
            oracle: Address
          }>
          marketAddresses: Record<string, Address>
        }
      }
    }
    aaveV3: {
      pool: Address
      rewards: Address
    }
    morpho: {
      blue: Address
      vaults: {
        [key in Tokens]: {
          [key: string]: Address
        }
      }
      markets: {
        [key in Tokens]: {
          [key: string]: Address
        }
      }
    }
    compoundV3: {
      pools: {
        [key in Tokens]: {
          cToken: Address
        }
      }
      rewards: Address
    }
  }
}
export interface FleetDefinition {
  fleetName: string
  symbol: string
  assetSymbol: string
  details: string
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
