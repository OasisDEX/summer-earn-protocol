import { Address } from 'viem'
import { BridgeConfig } from './bridge-types'

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
  SyrupArk = 'SyrupArk',
  SiloArk = 'SiloArk',
}

export const arkTypes = [
  { title: 'AaveV3Ark', value: ArkType.AaveV3Ark },
  { title: 'SparkArk', value: ArkType.SparkArk },
  { title: 'MorphoArk', value: ArkType.MorphoArk },
  { title: 'MorphoVaultArk', value: ArkType.MorphoVaultArk },
  { title: 'CompoundV3Ark', value: ArkType.CompoundV3Ark },
  { title: 'ERC4626Ark', value: ArkType.ERC4626Ark },
  { title: 'SkyUsdsArk', value: ArkType.SkyUsdsArk },
  { title: 'SkyUsdsPsm3Ark', value: ArkType.SkyUsdsPsm3Ark },
  { title: 'PendleLPArk', value: ArkType.PendleLPArk },
  { title: 'PendlePTArk', value: ArkType.PendlePTArk },
  { title: 'PendlePtOracleArk', value: ArkType.PendlePtOracleArk },
  { title: 'MoonwellArk', value: ArkType.MoonwellArk },
  { title: 'SyrupArk', value: ArkType.SyrupArk },
  { title: 'SiloArk', value: ArkType.SiloArk },
]

export interface Config {
  [key: string]: BaseConfig
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
  GEAR = 'gear',
  MORPHO = 'morpho',
}

export interface BaseConfig {
  deployedContracts: {
    gov: {
      summerGovernor: { address: string }
      summerToken: { address: string }
      timelock: { address: string }
      protocolAccessManager: { address: string }
      rewardsRedeemer: { address: string }
    }
    buyAndBurn: {
      buyAndBurn: { address: string }
    }
    core: {
      tipJar: { address: string }
      raft: { address: string }
      configurationManager: { address: string }
      harborCommand: { address: string }
      admiralsQuarters: { address: string }
      fleetCommanderRewardsManagerFactory: { address: string }
    }
  }
  tokens: {
    usdc: string
    dai: string
    weth: string
    usds: string
    stakedUsds: string
    morpho: string
    reul: string
    eurc: string
    seam: string
    ws: string
  }
  common: {
    chainId: string
    initialSupply: string
    swapProvider: string
    tipRate: string
    layerZero: {
      lzEndpoint: string
      eID: string
      lzExecutor: string
      sendUln302: string
      receiveUln302: string
      blockedMessageLib: string
      lzDeadDVN: string
      dvns: {
        [key: string]: {
          lzLabs: string
          stargate: string
        }
      }
    }
  }
  protocolSpecific: {
    syrup: {
      pools: Record<string, any>
    }
    aaveV3: {
      pool: string
      rewards: string
    }
    morpho: {
      blue: string
      urdFactory: string
      vaults: Record<string, Record<string, string>>
      markets: Record<string, Record<string, string>>
    }
    compoundV3: {
      pools: Record<string, { cToken: string }>
      rewards: string
    }
    erc4626: Record<string, Record<string, string>>
    moonwell: {
      pools: Record<string, { mToken: string }>
      comptroller: string
    }
    sky: {
      psm3: {
        usdc: string
      }
    }
  }
  bridge?: BridgeConfig
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
