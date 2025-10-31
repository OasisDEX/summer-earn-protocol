import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import { Address } from 'viem'
import { ArkType, BaseConfig, FleetConfig, Token } from '../../types/config-types'
import { deployAaveV3Ark } from '../arks/deploy-aavev3-ark'
import { deployAeraArk } from '../arks/deploy-aera-ark'
import { deployArmArk } from '../arks/deploy-arm-ark'
import { deployCompoundV3Ark } from '../arks/deploy-compoundv3-ark'
import { deployERC4626Ark } from '../arks/deploy-erc4626-ark'
import { deployFluidFTokenArk } from '../arks/deploy-fluid-ftoken-ark'
import { deployFluidLiteArk } from '../arks/deploy-fluid-lite-ark'
import { deployMoonwellArk } from '../arks/deploy-moonwell-ark'
import { deployMorphoArk } from '../arks/deploy-morpho-ark'
import { deployMorphoVaultArk } from '../arks/deploy-morpho-vault-ark'
import { deployOriginETHArk } from '../arks/deploy-origineth-ark'
import { deployPendleLPArk } from '../arks/deploy-pendle-lp-ark'
import { deployPendlePTArk } from '../arks/deploy-pendle-pt-ark'
import { deployPendlePTOracleArk } from '../arks/deploy-pendle-pt-oracle-ark'
import { deploySiloArk } from '../arks/deploy-silo-ark'
import { deploySiloArkV2 } from '../arks/deploy-silo-ark-v2'
import { deploySiloManagedVaultArk } from '../arks/deploy-silo-managed-vault-ark'
import { deploySiUSDArk } from '../arks/deploy-siusd-ark'
import { deploySkyRewardsArk } from '../arks/deploy-sky-rewards-ark'
import { deploySkyUsdsArk } from '../arks/deploy-sky-usds-ark'
import { deploySkyUsdsPsm3Ark } from '../arks/deploy-sky-usds-psm3-ark'
import { deploySparkArk } from '../arks/deploy-spark-ark'
import { deployStargateV2PoolArk } from '../arks/deploy-stargatev2-ark'
import { deploySyrupArk } from '../arks/deploy-syrup-ark'
import { deployCrossChainArk } from '../arks/deploy-xchain-ark'
import { CrossChainConfig } from '../lib/config/cross-chain'
import { ZERO_STRING } from '../lib/infrastructure/constants'
import {
  validateAddress,
  validateErc4626Address,
  validateMarketId,
  validateString,
  validateToken,
} from '../lib/infrastructure/validation'
import { BaseArkParams } from './ark-types'

export type ArkConfig = {
  type: ArkType
  params: {
    asset: string
    protocol?: string
    vaultName?: string
    targetChainId?: string
    depositCap?: string // For FluidLiteArk
    maxRebalanceOutflow?: string // For FluidLiteArk
    maxRebalanceInflow?: string // For FluidLiteArk
  }
}

export async function deployArk(
  arkConfig: ArkConfig,
  config: BaseConfig,
  fleetConfig: FleetConfig,
): Promise<Address> {
  const { type, params } = arkConfig
  const { asset, protocol, vaultName } = params

  console.log('Asset [Debug]:', asset)
  console.log('Protocol [Debug]:', protocol)
  const token = validateToken(config, asset)

  console.log('Deploying Ark [Debug]')
  const baseArkParams: BaseArkParams = {
    token: {
      address: config.tokens[token] as Address,
      symbol: token,
    },
    depositCap: params.depositCap || ZERO_STRING,
    maxRebalanceOutflow: params.maxRebalanceOutflow || ZERO_STRING,
    maxRebalanceInflow: params.maxRebalanceInflow || ZERO_STRING,
    fleetName: fleetConfig.fleetName,
  }

  let deployedArk: { ark: { address: string } } | null = null

  switch (type) {
    case ArkType.FluidLiteArk: {
      deployedArk = (await deployFluidLiteArk(config, baseArkParams)) ?? null
      break
    }
    case ArkType.AaveV3Ark: {
      deployedArk = (await deployAaveV3Ark(config, baseArkParams)) ?? null
      break
    }
    case ArkType.SparkArk: {
      deployedArk = (await deploySparkArk(config, baseArkParams)) ?? null
      break
    }
    case ArkType.CompoundV3Ark: {
      deployedArk = (await deployCompoundV3Ark(config, baseArkParams)) ?? null
      break
    }
    case ArkType.ERC4626Ark: {
      const validatedVaultName = validateString(vaultName, 'vault name')
      const vaultAddress = validateErc4626Address(
        config.protocolSpecific.erc4626[token][validatedVaultName],
        'ERC4626 vault',
      )
      deployedArk =
        (await deployERC4626Ark(config, {
          ...baseArkParams,
          vaultId: vaultAddress,
          vaultName: validatedVaultName,
        })) ?? null
      break
    }
    case ArkType.FluidFTokenArk: {
      deployedArk = (await deployFluidFTokenArk(config, baseArkParams)) ?? null
      break
    }
    case ArkType.MorphoArk: {
      const marketName = validateString(arkConfig.params.vaultName, 'vaultName')
      const marketId = validateMarketId(
        config.protocolSpecific.morpho.markets[token][marketName],
        'Morpho market ID',
      )
      deployedArk =
        (await deployMorphoArk(config, {
          ...baseArkParams,
          marketId,
          marketName,
        })) ?? null
      break
    }
    case ArkType.MorphoVaultArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const marketId = validateMarketId(
        config.protocolSpecific.morpho.vaults[token][vaultName],
        'Morpho vault market ID',
      )
      deployedArk =
        (await deployMorphoVaultArk(config, {
          ...baseArkParams,
          vaultId: marketId as `0x${string}`,
          vaultName: vaultName,
        })) ?? null
      break
    }
    case ArkType.PendleLPArk: {
      const marketName = validateString(arkConfig.params.vaultName, 'marketName')
      const pendleMarket = validateAddress(
        config.protocolSpecific.pendle.markets[token].marketAddresses[marketName],
        `Pendle-${token}`,
      )
      const pendleLPParams = {
        ...baseArkParams,
        marketId: pendleMarket,
        marketName: marketName,
      }
      deployedArk = (await deployPendleLPArk(config, pendleLPParams)) ?? null
      break
    }

    case 'PendlePTArk': {
      const marketName = validateString(arkConfig.params.vaultName, 'marketName')
      const pendleMarket = validateAddress(
        config.protocolSpecific.pendle.markets[token].marketAddresses[marketName],
        `Pendle-${token}`,
      )
      const pendlePTParams = {
        ...baseArkParams,
        marketId: pendleMarket,
        marketName: marketName,
      }
      deployedArk = (await deployPendlePTArk(config, pendlePTParams)) ?? null
      break
    }

    case 'PendlePtOracleArk': {
      const marketName = validateString(arkConfig.params.vaultName, 'marketName')
      const pendleMarket = validateAddress(
        config.protocolSpecific.pendle.markets[token].marketAddresses[marketName],
        `Pendle-${token}`,
      )
      const marketAssetOracle = validateAddress(
        config.protocolSpecific.pendle.markets[token].swapInTokens[0].oracle,
        `Pendle-${token}`,
      )
      const pendlePTOracleParams = {
        ...baseArkParams,
        marketId: pendleMarket,
        marketName: marketName,
        marketAssetOracle,
      }
      deployedArk = (await deployPendlePTOracleArk(config, pendlePTOracleParams)) ?? null
      break
    }
    case ArkType.SkyUsdsArk: {
      deployedArk = (await deploySkyUsdsArk(config, baseArkParams)) ?? null
      break
    }
    case ArkType.SkyUsdsPsm3Ark: {
      deployedArk = (await deploySkyUsdsPsm3Ark(config, baseArkParams)) ?? null
      break
    }
    case ArkType.MoonwellArk: {
      deployedArk =
        (await deployMoonwellArk(config, {
          ...baseArkParams,
        })) ?? null
      break
    }
    case ArkType.SyrupArk: {
      deployedArk =
        (await deploySyrupArk(config, {
          ...baseArkParams,
        })) ?? null
      break
    }
    case ArkType.SkyRewardsArk: {
      deployedArk = (await deploySkyRewardsArk(config, baseArkParams)) ?? null
      break
    }
    case ArkType.SiloArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const vaultId = validateErc4626Address(
        config.protocolSpecific.silo.pools[token][vaultName],
        `Silo-${vaultName}`,
      )
      const siloParams = {
        ...baseArkParams,
        siloId: vaultId,
        siloName: vaultName,
      }
      deployedArk = (await deploySiloArk(config, siloParams)) ?? null
      break
    }

    case ArkType.CrossChainArk: {
      const targetChainId = Number(arkConfig.params.targetChainId)
      const targetProtocol = arkConfig.params.protocol

      if (!targetChainId || !targetProtocol) {
        console.log(kleur.red('Missing targetChainId or protocol in ark configuration.'))
        throw new Error('CrossChainArk requires targetChainId and protocol parameters')
      }

      // Get cross-chain config
      const configDir = path.join(process.cwd(), 'config', 'cross-chain')
      const configFiles = fs.readdirSync(configDir).filter((file) => file.endsWith('.json'))

      if (configFiles.length === 0) {
        throw new Error('No cross-chain config files found')
      }

      // Load the config
      const configPath = path.join(configDir, configFiles[0])
      const crossChainConfig = JSON.parse(fs.readFileSync(configPath, 'utf8')) as CrossChainConfig

      // Find the protocol configuration
      const destination = crossChainConfig.destinations.find((d) => d.chainId === targetChainId)
      if (!destination) {
        throw new Error(`Destination with chain ID ${targetChainId} not found in config`)
      }

      const protocol = destination.protocols.find((p) => p.protocol === targetProtocol)
      if (!protocol) {
        throw new Error(
          `Protocol ${targetProtocol} not found for chain ID ${targetChainId} in config`,
        )
      }

      deployedArk =
        (await deployCrossChainArk(config, {
          ...baseArkParams,
          targetChainId,
          targetProtocol,
          // bridgeRouter removed - will be auto-populated
          ...protocol,
        })) ?? null
      break
    }

    case ArkType.SiloArkV2: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const vaultId = validateErc4626Address(
        config.protocolSpecific.silo.pools[token][vaultName],
        `Silo-${vaultName}`,
      )
      const siloParams = {
        ...baseArkParams,
        siloId: vaultId,
        siloName: vaultName,
      }
      deployedArk = (await deploySiloArkV2(config, siloParams)) ?? null
      break
    }
    case ArkType.OriginETHArk: {
      deployedArk = (await deployOriginETHArk(config, baseArkParams)) ?? null
      break
    }
    case ArkType.ArmArk: {
      // ArmArk only supports WETH
      if (token !== Token.WETH) {
        throw new Error('ArmArk only supports WETH as the asset')
      }
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const armArkParams = {
        ...baseArkParams,
        vaultName: vaultName,
      }
      deployedArk = (await deployArmArk(config, armArkParams)) ?? null
      break
    }
    case ArkType.SiloManagedVaultArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const vaultId = validateErc4626Address(
        config.protocolSpecific.silo.vaults[token][vaultName],
        `Silo-${vaultName}`,
      )
      const siloManagedVaultParams = {
        ...baseArkParams,
        vaultId: vaultId,
        vaultName: vaultName,
      }
      deployedArk = (await deploySiloManagedVaultArk(config, siloManagedVaultParams)) ?? null
      break
    }
    case ArkType.AeraArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const provisioner = validateAddress(
        config.protocolSpecific.gauntlet.vaults[token][vaultName].provisioner,
        `Aera-${vaultName}`,
      )
      deployedArk =
        (await deployAeraArk(config, {
          ...baseArkParams,
          provisioner: provisioner,
          vaultName: vaultName,
        })) ?? null
      break
    }
    case ArkType.StargateV2PoolArk: {
      const stargatePoolAddress = validateAddress(
        config.protocolSpecific.stargate.pools[token],
        `StargateV2-${token}`,
      )
      deployedArk =
        (await deployStargateV2PoolArk(config, {
          ...baseArkParams,
          stargatePoolAddress: stargatePoolAddress,
        })) ?? null
      break
    }
    case ArkType.SiUSDArk: {
      // SiUSDArk only supports USDC
      if (token !== Token.USDC) {
        throw new Error('SiUSDArk only supports USDC as the asset')
      }
      const gateway = validateAddress(config.protocolSpecific.infinifi?.gateway, 'InfiniFi Gateway')
      const siUSD = validateErc4626Address(config.protocolSpecific.infinifi?.siUSD, 'siUSD vault')
      // Enforce USDC + config validations as in deployArk
      deployedArk =
        (await deploySiUSDArk(config, {
          ...baseArkParams,
          gateway: gateway,
          siUSD: siUSD,
        })) ?? null
      break
    }
    default:
      throw new Error(`Unknown Ark type: ${type}`)
  }

  if (!deployedArk?.ark?.address) {
    throw new Error(`Failed to deploy ${type}`)
  }

  return deployedArk.ark.address as Address
}

export async function deployArkInteractive(arkType: ArkType, config: BaseConfig) {
  let deployedArk: { ark: { address: string } } | null = null

  switch (arkType) {
    case ArkType.SyrupArk:
      deployedArk = (await deploySyrupArk(config)) ?? null
      break
    case ArkType.SkyRewardsArk:
      deployedArk = (await deploySkyRewardsArk(config)) ?? null
      break
    case ArkType.AaveV3Ark:
      deployedArk = (await deployAaveV3Ark(config)) ?? null
      break
    case ArkType.SparkArk:
      deployedArk = (await deploySparkArk(config)) ?? null
      break
    case ArkType.MoonwellArk:
      deployedArk = (await deployMoonwellArk(config)) ?? null
      break
    case ArkType.CompoundV3Ark:
      deployedArk = (await deployCompoundV3Ark(config)) ?? null
      break

    case ArkType.ERC4626Ark:
      deployedArk = (await deployERC4626Ark(config)) ?? null
      break

    case ArkType.MorphoArk: {
      deployedArk = (await deployMorphoArk(config)) ?? null
      break
    }

    case ArkType.MorphoVaultArk: {
      deployedArk = (await deployMorphoVaultArk(config)) ?? null
      break
    }

    case ArkType.PendleLPArk: {
      deployedArk = (await deployPendleLPArk(config)) ?? null
      break
    }

    case ArkType.PendlePTArk: {
      deployedArk = (await deployPendlePTArk(config)) ?? null
      break
    }

    case ArkType.PendlePtOracleArk: {
      deployedArk = (await deployPendlePTOracleArk(config)) ?? null
      break
    }

    case ArkType.SkyUsdsArk: {
      deployedArk = (await deploySkyUsdsArk(config)) ?? null
      break
    }

    case ArkType.SkyUsdsPsm3Ark: {
      deployedArk = (await deploySkyUsdsPsm3Ark(config)) ?? null
      break
    }

    case ArkType.SiloArk: {
      deployedArk = (await deploySiloArk(config)) ?? null
      break
    }

    case ArkType.AeraArk: {
      deployedArk = (await deployAeraArk(config)) ?? null
      break
    }

    case ArkType.SiloManagedVaultArk: {
      deployedArk = (await deploySiloManagedVaultArk(config)) ?? null
      break
    }
    case ArkType.ArmArk: {
      deployedArk = (await deployArmArk(config)) ?? null
      break
    }

    case ArkType.CrossChainArk: {
      deployedArk = (await deployCrossChainArk(config)) ?? null
      break
    }

    case ArkType.StargateV2PoolArk: {
      deployedArk = (await deployStargateV2PoolArk(config)) ?? null
      break
    }

    case ArkType.SiUSDArk: {
      deployedArk = (await deploySiUSDArk(config)) ?? null
      break
    }

    case ArkType.FluidFTokenArk: {
      deployedArk = (await deployFluidFTokenArk(config)) ?? null
      break
    }
    case ArkType.FluidLiteArk: {
      deployedArk = (await deployFluidLiteArk(config)) ?? null
      break
    }

    default:
      throw new Error(`Unknown Ark type: ${arkType}`)
  }

  if (!deployedArk?.ark?.address) {
    throw new Error(`Failed to deploy ${arkType}`)
  }

  return deployedArk.ark.address as Address
}
