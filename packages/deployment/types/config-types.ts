import { Address } from 'viem'
import { BuyAndBurnContracts } from '../ignition/modules/buy-and-burn'
import { CoreContracts } from '../ignition/modules/core'
import { GovContracts } from '../ignition/modules/gov'

export enum SupportedNetworks {
  MAINNET = 'mainnet',
  BASE = 'base',
  ARBITRUM = 'arbitrum',
  SONIC = 'sonic',
}
// Supported Arks
export enum ArkType {
  AaveV3Ark = 'AaveV3Ark',
  SparkArk = 'SparkArk',
  CompoundV3Ark = 'CompoundV3Ark',
  ERC4626Ark = 'ERC4626Ark',
  MorphoArk = 'MorphoArk',
  MorphoVaultArk = 'MorphoVaultArk',
  PendleLPArk = 'PendleLPArk',
  PendlePTArk = 'PendlePTArk',
  PendlePtOracleArk = 'PendlePtOracleArk',
  SkyUsdsArk = 'SkyUsdsArk',
  SkyUsdsPsm3Ark = 'SkyUsdsPsm3Ark',
  MoonwellArk = 'MoonwellArk',
}

export interface Config {
  [SupportedNetworks.MAINNET]: BaseConfig
  [SupportedNetworks.BASE]: BaseConfig
  [SupportedNetworks.ARBITRUM]: BaseConfig
}

export enum Token {
  USDC = 'usdc',
  DAI = 'dai',
  USDT = 'usdt',
  USDE = 'usde',
  USDCE = 'usdce',
  USDS = 'usds',
  STAKED_USDS = 'stakedUsds',
  WETH = 'weth',
  EURC = 'eurc',
  SEAM = 'seam',
  REUL = 'reul',
  WELL = 'well',
  WS = 'ws',
}

export interface BaseConfig {
  deployedContracts: {
    core: CoreContracts
    gov: GovContracts
    buyAndBurn: BuyAndBurnContracts
  }
  common: {
    chainId: string
    initialSupply: string
    layerZero: {
      lzEndpoint: Address
      eID: string
      lzExecutor: Address
      sendUln302: Address
      receiveUln302: Address
      blockedMessageLib: Address
      lzDeadDVN: Address
      dvns: {
        sonic: Record<string, Address>
      }
    }
    swapProvider: Address
    tipRate: string
  }
  tokens: {
    [key in Token]: Address
  }
  protocolSpecific: {
    erc4626: {
      [key in Token]: {
        [key: string]: Address
      }
    }
    pendle: {
      router: Address
      'lp-oracle': Address
      markets: {
        [key in Token]: {
          swapInTokens: Array<{
            token: Token
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
    spark: {
      pool: Address
      rewards: Address
    }
    morpho: {
      blue: Address
      urdFactory: Address
      vaults: {
        [key in Token]: {
          [key: string]: Address
        }
      }
      markets: {
        [key in Token]: {
          [key: string]: Address
        }
      }
    }
    compoundV3: {
      pools: {
        [key in Token]: {
          cToken: Address
        }
      }
      rewards: Address
    }
    sky: {
      psmLite: {
        [key in Token]: Address
      }
      psm3: {
        [key in Token]: Address
      }
    }
    moonwell: {
      pools: {
        [key in Token]: {
          mToken: Address
        }
      }
      comptroller: Address
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

export interface FleetConfig {
  fleetName: string
  symbol: string
  assetSymbol: string
  initialMinimumBufferBalance: string
  initialRebalanceCooldown: string
  depositCap: string
  initialTipRate: string
  network: string
  rewardTokens: string[]
  rewardAmounts: string[]
  rewardsDuration: number[]
  bridgeAmount: string
  arks: ArkConfig[]
  discourseURL?: string
  sipNumber?: string
  details: string
  curator?: Address
}

export interface FleetDeployment {
  fleetName: string
  fleetSymbol: string
  assetSymbol: string
  fleetAddress: Address
  bufferArkAddress: Address
  network: string
  arks: Address[]
}
