import { Address } from 'viem'

import { CoreContracts as CoreContractsBase } from '../ignition/modules/core'
import { FleetDetails } from '../scripts/helpers/zod-schemas'
import { DeployedBridge } from './bridge-types'

export enum SupportedNetworks {
  MAINNET = 'mainnet',
  BASE = 'base',
  ARBITRUM = 'arbitrum',
  SONIC = 'sonic',
  HYPERLIQUID = 'hyperliquid',
}
// Supported Arks
export enum ArkType {
  AaveV3Ark = 'AaveV3Ark',
  SparkArk = 'SparkArk',
  CompoundV3Ark = 'CompoundV3Ark',
  CrossChainArk = 'CrossChainArk',
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
  SiloArkV2 = 'SiloArkV2',
  SiloManagedVaultArk = 'SiloManagedVaultArk',
  OriginETHArk = 'OriginETHArk',
  ArmArk = 'ArmArk',
  FluidLiteArk = 'FluidLiteArk',
  AeraArk = 'AeraArk',
  StargateV2PoolArk = 'StargateV2PoolArk',
  SiUSDArk = 'SiUSDArk',
  FluidFTokenArk = 'FluidFTokenArk',
  PsmLiteERC4626Ark = 'PsmLiteERC4626Ark',
  Psm3ERC4626Ark = 'Psm3ERC4626Ark',
  HyperlendArk = 'HyperlendArk',
  HypurrArk = 'HypurrArk',
  MorphoV2VaultArk = 'MorphoV2VaultArk',
}

export const arkTypes = [
  { title: 'AaveV3Ark', value: ArkType.AaveV3Ark },
  { title: 'SparkArk', value: ArkType.SparkArk },
  { title: 'MorphoArk', value: ArkType.MorphoArk },
  { title: 'MorphoVaultArk', value: ArkType.MorphoVaultArk },
  { title: 'CompoundV3Ark', value: ArkType.CompoundV3Ark },
  { title: 'CrossChainArk', value: ArkType.CrossChainArk },
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
  { title: 'AeraArk', value: ArkType.AeraArk },
  { title: 'StargateV2PoolArk', value: ArkType.StargateV2PoolArk },
  { title: 'SiUSDArk', value: ArkType.SiUSDArk },
  { title: 'FluidFTokenArk', value: ArkType.FluidFTokenArk },
  { title: 'PsmLiteERC4626Ark', value: ArkType.PsmLiteERC4626Ark },
  { title: 'Psm3ERC4626Ark', value: ArkType.Psm3ERC4626Ark },
  { title: 'HyperlendArk', value: ArkType.HyperlendArk },
  { title: 'HypurrArk', value: ArkType.HypurrArk },
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
  ASONW = 'asonw',
  WRAPPED_NATIVE = 'wrappedNative',
}

export interface BaseConfig {
  deployedContracts: {
    gov: {
      summerGovernor: { address: string }
      summerToken: { address: string }
      timelock: { address: string }
      protocolAccessManager: { address: string }
      rewardsRedeemer: { address: string }
      summerVestingFactory?: { address: string }
      summerVestingFactoryV2?: { address: string }
      timelockGuardFactory?: { address: string }
    }
    govV2: {
      summerGovernor: { address: string }
      summerGovernanceToken: { address: string }
      timelock: { address: string }
      protocolAccessManager: { address: string }
      summerStaking: { address: string }
      summerVestingWalletsEscrow: { address: string }
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
      institutionalVaultRegistry?: { address: string }
      daoTipJar?: { address: string }
    }
    bridge?: {
      bridgeRouter: { address: string }
      bridgeQueue: { address: string }
      crossChainRegistry: { address: string }
      adapters?: {
        layerZero?: { address: string }
        stargate?: { address: string }
      }
    }
  }
  tokens: {
    [key in Token]: Address
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
          secondDvn: string
        }
      }
    }
  }
  protocolSpecific: {
    aaveV3: {
      pool: string
      rewards: string
    }
    spark: {
      pool: string
      rewards: string
    }
    morpho: {
      blue: string
      urdFactory: string
      vaults: Record<string, Record<string, string>>
      vaultsV2: Record<string, Record<string, string>>
      markets: Record<string, Record<string, string>>
    }
    compoundV3: {
      pools: Record<string, { cToken: string }>
      rewards: string
    }
    erc4626: Record<string, Record<string, string>>
    sky: {
      psmLite: {
        [key in Token]: Address
      }
      psm3: {
        [key in Token]: Address
      }
      staking: Record<string, Address>
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
      fToken: {
        [key in Token]: {
          fToken: Address
          merkleDistributor: Address
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
    aera: {
      vaults: {
        [key in Token]: {
          [key: string]: {
            provisioner: Address
          }
        }
      }
    }
    stargate: {
      staking: Address
      pools: {
        [key in Token]: Address
      }
    }
    infinifi?: {
      gateway: Address
      siUSD: Address
    }
    pendle: {
      router: Address
      'lp-oracle': Address
      markets: Record<
        Token,
        {
          marketAddresses: Record<string, Address>
          swapInTokens: {
            token: Token
            oracle: Address
          }[]
        }
      >
    }
    hyperlend: {
      pool: Address
      rewards: Address
    }
    hypurr: {
      pool: Address
      rewards: Address
    }
  }
  bridge?: DeployedBridge
}

export interface ArkConfig {
  type: ArkType
  params: {
    asset: string
    protocol: string
    vaultName?: string // For ERC4626Ark
    rewardToken?: string // For SkyRewardsArk (e.g. 'sky' | 'spk')
    depositCap?: string // For FluidLiteArk
    maxRebalanceOutflow?: string // For FluidLiteArk
    maxRebalanceInflow?: string // For FluidLiteArk
    maxDepositPercentageOfTVL?: string // For ArkConfigProvider
    targetChainId?: string // For CrossChainArk
    fleetName?: string // For CrossChainArk
    vaultToken?: string // for arks with underlying token different than fleet asset
  }
}

export interface FleetConfig {
  fleetName: string
  isBummer?: boolean
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
  details: FleetDetails
  curator: Address
  discourseURL?: string
  sipNumber?: string
  keeper?: Address
}

export interface FleetDeployment {
  fleetName: string
  isBummer?: boolean
  fleetSymbol: string
  assetSymbol: string
  fleetAddress: Address
  bufferArkAddress: Address
  network: string
  arks: Address[]
  initialMinimumBufferBalance?: string
  initialRebalanceCooldown?: string
  depositCap?: string
  initialTipRate?: string
  details: FleetDetails
}

// Extend CoreContracts to include InstitutionalVaultRegistry for networks
export interface CoreContracts extends CoreContractsBase {
  institutionalVaultRegistry?: { address: Address }
}
