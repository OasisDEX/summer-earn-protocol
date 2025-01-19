import { Address } from 'viem'
import { BuyAndBurnContracts } from '../ignition/modules/buy-and-burn'
import { CoreContracts } from '../ignition/modules/core'
import { GovContracts } from '../ignition/modules/gov'

export enum SupportedNetworks {
  MAINNET = 'mainnet',
  BASE = 'base',
  ARBITRUM = 'arbitrum',
}
// Supported Arks
export enum ArkType {
  AaveV3Ark = 'AaveV3Ark',
  CompoundV3Ark = 'CompoundV3Ark',
  ERC4626Ark = 'ERC4626Ark',
  MorphoArk = 'MorphoArk',
  MorphoVaultArk = 'MorphoVaultArk',
  PendleLPArk = 'PendleLPArk',
  PendlePTArk = 'PendlePTArk',
  PendlePtOracleArk = 'PendlePtOracleArk',
  SkyUsdsArk = 'SkyUsdsArk',
  SkyUsdsPsm3Ark = 'SkyUsdsPsm3Ark',
}

export interface Config {
  [SupportedNetworks.MAINNET]: BaseConfig
  [SupportedNetworks.BASE]: BaseConfig
  [SupportedNetworks.ARBITRUM]: BaseConfig
}

export enum Tokens {
  USDC = 'usdc',
  DAI = 'dai',
  USDT = 'usdt',
  USDE = 'usde',
  USDCE = 'usdce',
  USDS = 'usds',
  STAKED_USDS = 'stakedUsds',
  WETH = 'weth',
}
export type TokenType =
  | Tokens.DAI
  | Tokens.USDC
  | Tokens.USDT
  | Tokens.USDE
  | Tokens.USDCE
  | Tokens.USDS
  | Tokens.STAKED_USDS
  | Tokens.WETH
export interface BaseConfig {
  deployedContracts: {
    core: CoreContracts
    gov: GovContracts
    buyAndBurn: BuyAndBurnContracts
  }
  common: {
    initialSupply: string
    layerZero: {
      lzEndpoint: Address
      eID: string
    }
    treasury: Address
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
      urdFactory: Address
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
    sky: {
      psmLite: {
        [key in Tokens]: Address
      }
      psm3: {
        [key in Tokens]: Address
      }
    }
  }
}

export interface ArkConfig {
  type: ArkType
  params: {
    asset: string
    protocol: string
    vaultName?: string // For ERC4626Ark
  }
}

export interface FleetDefinition {
  fleetName: string
  symbol: string
  assetSymbol: string
  initialMinimumBufferBalance: string
  initialRebalanceCooldown: string
  depositCap: string
  initialTipRate: string
  network: string
  arks: ArkConfig[]
  details: string
}
