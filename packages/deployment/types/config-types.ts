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
  SyrupArk = 'SyrupArk',
  SkyRewardsArk = 'SkyRewardsArk',
  SiloArk = 'SiloArk',
  SiloManagedVaultArk = 'SiloManagedVaultArk',
  OriginETHArk = 'OriginETHArk',
  ArmArk = 'ArmArk',
  FluidLiteArk = 'FluidLiteArk',
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
  { title: 'SkyRewardsArk', value: ArkType.SkyRewardsArk },
  { title: 'SiloArk', value: ArkType.SiloArk },
  { title: 'SiloManagedVaultArk', value: ArkType.SiloManagedVaultArk },
  { title: 'OriginETHArk', value: ArkType.OriginETHArk },
  { title: 'ArmArk', value: ArkType.ArmArk },
  { title: 'FluidLiteArk', value: ArkType.FluidLiteArk },
]

export interface Config {
  [SupportedNetworks.MAINNET]: BaseConfig
  [SupportedNetworks.BASE]: BaseConfig
  [SupportedNetworks.ARBITRUM]: BaseConfig
  [SupportedNetworks.SONIC]: BaseConfig
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
  STETH = 'steth',
  EURC = 'eurc',
  SEAM = 'seam',
  REUL = 'reul',
  WELL = 'well',
  WS = 'ws',
  GEAR = 'gear',
  MORPHO = 'morpho',
  SYRUP = 'syrup',
  SILO = 'silo',
  SKY = 'sky',
  XSILO = 'xsilo',
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
      staking: {
        sky: Address
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
    syrup: {
      pools: {
        [key in Token]: {
          syrup: Address
          router: Address
        }
      }
    }
    silo: {
      pools: {
        [key in Token]: {
          [key: string]: Address
        }
      }
      vaults: {
        [key in Token]: {
          [key: string]: Address
        }
      }
    }
    fluid: {
      lite: {
        [key in Token]: {
          wrapper: Address
          vault: Address
          withdrawalQueue: Address
        }
      }
    }
    originETH: {
      originETH: Address
      arm: Address
      arms: {
        [key in Token]: {
          [key: string]: Address
        }
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
    depositCap?: string // For FluidLiteArk
    maxRebalanceOutflow?: string // For FluidLiteArk
    maxRebalanceInflow?: string // For FluidLiteArk
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
