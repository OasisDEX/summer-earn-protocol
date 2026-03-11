import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import { Address } from 'viem'
import { ArkConfig, ArkType, BaseConfig, FleetConfig, Token } from '../../types/config-types'
import { deployAaveV3Ark } from '../arks/deploy-aavev3-ark'
import { deployAeraArk } from '../arks/deploy-aera-ark'
import { deployArmArk } from '../arks/deploy-arm-ark'
import { deployCompoundV3Ark } from '../arks/deploy-compoundv3-ark'
import { deployCrossChainArk } from '../arks/deploy-cross-chain-ark'
import { deployERC4626Ark } from '../arks/deploy-erc4626-ark'
import { deployFluidFTokenArk } from '../arks/deploy-fluid-ftoken-ark'
import { deployFluidLiteArk } from '../arks/deploy-fluid-lite-ark'
import { deployHyperlendArk } from '../arks/deploy-hyperlend-ark'
import { deployHypurrArk } from '../arks/deploy-hypurr-ark'
import { deployMoonwellArk } from '../arks/deploy-moonwell-ark'
import { deployMorphoArk } from '../arks/deploy-morpho-ark'
import { deployMorphoVaultArk } from '../arks/deploy-morpho-vault-ark'
import { deployOriginETHArk } from '../arks/deploy-origineth-ark'
import { deployPendleLPArk } from '../arks/deploy-pendle-lp-ark'
import { deployPendlePTArk } from '../arks/deploy-pendle-pt-ark'
import { deployPendlePTOracleArk } from '../arks/deploy-pendle-pt-oracle-ark'
import { deployPsmERC4626Ark } from '../arks/deploy-psm-erc4626-ark'
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
import {
  validateAddress,
  validateConfigAddressEntry,
  validateErc4626Address,
  validateMarketId,
  validateString,
  validateToken,
} from '../helpers/validation'
import { ZERO_STRING } from './constants'
import { deployMorphoV2VaultArk } from '../arks/deploy-morpho-v2-vault-ark'

export type BaseArkParams = {
  token: {
    address: Address
    symbol: Token
  }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  maxDepositPercentageOfTVL: string
  fleetName: string
  isBummer?: boolean
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
    maxDepositPercentageOfTVL: params.maxDepositPercentageOfTVL || ZERO_STRING,
    fleetName: fleetConfig.fleetName,
    isBummer: fleetConfig.isBummer,
  }

  let deployedArk

  switch (type) {
    case ArkType.FluidLiteArk: {
      const ark = await deployFluidLiteArk(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.AaveV3Ark: {
      const ark = await deployAaveV3Ark(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.HyperlendArk: {
      const ark = await deployHyperlendArk(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.HypurrArk: {
      const ark = await deployHypurrArk(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.SparkArk: {
      const ark = await deploySparkArk(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.CompoundV3Ark: {
      const ark = await deployCompoundV3Ark(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.ERC4626Ark: {
      const validatedVaultName = validateString(vaultName, 'vault name')
      const vaultAddress = validateConfigAddressEntry(
        config.protocolSpecific.erc4626[token],
        validatedVaultName,
        'ERC4626 vault',
      )
      const ark = await deployERC4626Ark(config, {
        ...baseArkParams,
        vaultId: vaultAddress,
        vaultName: validatedVaultName,
      })
      deployedArk = ark
      break
    }
    case ArkType.FluidFTokenArk: {
      const ark = await deployFluidFTokenArk(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.MorphoArk: {
      const marketName = validateString(arkConfig.params.vaultName, 'vaultName')
      const marketId = validateMarketId(
        config.protocolSpecific.morpho.markets[token][marketName],
        'Morpho market ID',
      )
      const ark = await deployMorphoArk(config, {
        ...baseArkParams,
        marketId,
        marketName,
      })
      deployedArk = ark
      break
    }
    case ArkType.MorphoVaultArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const vaultId = validateConfigAddressEntry(
        config.protocolSpecific.morpho.vaults[token],
        vaultName,
        'Morpho vault ID',
      )
      const ark = await deployMorphoVaultArk(config, {
        ...baseArkParams,
        vaultId: vaultId,
        vaultName: vaultName,
      })
      deployedArk = ark
      break
    }
    case ArkType.MorphoV2VaultArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const vaultId = validateConfigAddressEntry(
        config.protocolSpecific.morpho.vaultsV2[token],
        vaultName,
        'Morpho V2 vault ID',
      )
      const ark = await deployMorphoV2VaultArk(config, {
        ...baseArkParams,
        vaultId: vaultId,
        vaultName: vaultName,
      })
      deployedArk = ark
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
      deployedArk = await deployPendleLPArk(config, pendleLPParams)
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
      deployedArk = await deployPendlePTArk(config, pendlePTParams)
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
      deployedArk = await deployPendlePTOracleArk(config, pendlePTOracleParams)
      break
    }
    case ArkType.SkyUsdsArk: {
      const ark = await deploySkyUsdsArk(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.SkyUsdsPsm3Ark: {
      const ark = await deploySkyUsdsPsm3Ark(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.MoonwellArk: {
      const ark = await deployMoonwellArk(config, {
        ...baseArkParams,
      })
      deployedArk = ark
      break
    }
    case ArkType.SyrupArk: {
      const ark = await deploySyrupArk(config, {
        ...baseArkParams,
      })
      deployedArk = ark
      break
    }
    case ArkType.SkyRewardsArk: {
      const ark = await deploySkyRewardsArk(config, {
        ...baseArkParams,
        rewardToken: arkConfig.params.rewardToken,
      })
      deployedArk = ark
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
      deployedArk = await deploySiloArk(config, siloParams)
      break
    }

    case ArkType.CrossChainArk: {
      const targetChainId = Number(arkConfig.params.targetChainId)
      const targetProtocol = arkConfig.params.protocol

      if (!targetChainId || !targetProtocol) {
        console.log(kleur.red('Missing targetChainId or protocol in ark configuration.'))
        throw new Error('CrossChainArk requires targetChainId and protocol parameters')
      }

      // Get bridge components from config
      const bridgeQueue = config.deployedContracts.bridge?.bridgeQueue?.address as Address
      const bridgeRouter = config.deployedContracts.bridge?.bridgeRouter?.address as Address

      if (!bridgeQueue || !bridgeRouter) {
        throw new Error('Bridge components not found in config')
      }

      // Get cross-chain config
      const configDir = path.join(process.cwd(), 'config', 'cross-chain')
      const configFiles = fs.readdirSync(configDir).filter((file) => file.endsWith('.json'))

      if (configFiles.length === 0) {
        throw new Error('No cross-chain config files found')
      }

      // Load the config
      const configPath = path.join(configDir, configFiles[0])
      const crossChainConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'))

      // Find the protocol configuration
      const destination = crossChainConfig.destinations.find(
        (d: any) => d.chainId === targetChainId,
      )
      if (!destination) {
        throw new Error(`Destination with chain ID ${targetChainId} not found in config`)
      }

      const protocol = destination.protocols.find((p: any) => p.protocol === targetProtocol)

      deployedArk = await deployCrossChainArk(config, {
        ...baseArkParams,
        targetChainId,
        targetProtocol,
        bridgeQueue,
        bridgeRouter,
        ...protocol,
      })
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
      deployedArk = await deploySiloArkV2(config, siloParams)
      break
    }
    case ArkType.OriginETHArk: {
      const ark = await deployOriginETHArk(config, baseArkParams)
      deployedArk = ark
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
      const ark = await deployArmArk(config, armArkParams)
      deployedArk = ark
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
      deployedArk = await deploySiloManagedVaultArk(config, siloManagedVaultParams)
      break
    }
    case ArkType.AeraArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const provisioner = validateAddress(
        config.protocolSpecific.aera.vaults[token][vaultName].provisioner,
        `Aera-${vaultName}`,
      )
      const ark = await deployAeraArk(config, {
        ...baseArkParams,
        provisioner: provisioner,
        vaultName: vaultName,
      })
      deployedArk = ark
      break
    }
    case ArkType.StargateV2PoolArk: {
      const stargatePoolAddress = validateAddress(
        config.protocolSpecific.stargate.pools[token],
        `StargateV2-${token}`,
      )
      const ark = await deployStargateV2PoolArk(config, {
        ...baseArkParams,
        stargatePoolAddress: stargatePoolAddress,
      })
      deployedArk = ark
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
      const ark = await deploySiUSDArk(config, {
        ...baseArkParams,
        gateway: gateway,
        siUSD: siUSD,
      })
      deployedArk = ark
      break
    }
    case ArkType.PsmLiteERC4626Ark: {
      const vaultToken = validateToken(config, arkConfig.params.vaultToken || '')
      const erc4626VaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const erc4626VaultId = validateErc4626Address(
        config.protocolSpecific.erc4626[vaultToken][erc4626VaultName],
        `ERC4626-${erc4626VaultName}`,
      )
      deployedArk = await deployPsmERC4626Ark(config, {
        ...baseArkParams,
        psmType: 'psmlite',
        vaultToken: config.tokens[vaultToken],
        vaultId: erc4626VaultId,
        vaultName: erc4626VaultName,
      })
      break
    }

    case ArkType.Psm3ERC4626Ark: {
      const vaultToken = validateToken(config, arkConfig.params.vaultToken || '')
      const erc4626VaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const erc4626VaultId = validateErc4626Address(
        config.protocolSpecific.erc4626[vaultToken][erc4626VaultName],
        `ERC4626-${erc4626VaultName}`,
      )
      deployedArk = await deployPsmERC4626Ark(config, {
        ...baseArkParams,
        psmType: 'psm3',
        vaultToken: config.tokens[vaultToken],
        vaultId: erc4626VaultId,
        vaultName: erc4626VaultName,
      })
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
  let deployedArk: any

  switch (arkType) {
    case ArkType.SyrupArk:
      deployedArk = await deploySyrupArk(config)
      break
    case ArkType.SkyRewardsArk:
      deployedArk = await deploySkyRewardsArk(config)
      break
    case ArkType.AaveV3Ark:
      deployedArk = await deployAaveV3Ark(config)
      break
    case ArkType.SparkArk:
      deployedArk = await deploySparkArk(config)
      break
    case ArkType.HypurrArk:
      deployedArk = await deployHypurrArk(config)
      break
    case ArkType.MoonwellArk:
      deployedArk = await deployMoonwellArk(config)
      break
    case ArkType.CompoundV3Ark:
      deployedArk = await deployCompoundV3Ark(config)
      break

    case ArkType.ERC4626Ark:
      deployedArk = await deployERC4626Ark(config)
      break

    case ArkType.MorphoArk: {
      deployedArk = await deployMorphoArk(config)
      break
    }

    case ArkType.MorphoVaultArk: {
      deployedArk = await deployMorphoVaultArk(config)
      break
    }

    case ArkType.PendleLPArk: {
      deployedArk = await deployPendleLPArk(config)
      break
    }

    case ArkType.PendlePTArk: {
      deployedArk = await deployPendlePTArk(config)
      break
    }

    case ArkType.PendlePtOracleArk: {
      deployedArk = await deployPendlePTOracleArk(config)
      break
    }

    case ArkType.SkyUsdsArk: {
      deployedArk = await deploySkyUsdsArk(config)
      break
    }

    case ArkType.SkyUsdsPsm3Ark: {
      deployedArk = await deploySkyUsdsPsm3Ark(config)
      break
    }

    case ArkType.SiloArk: {
      deployedArk = await deploySiloArk(config)
      break
    }

    case ArkType.AeraArk: {
      deployedArk = await deployAeraArk(config)
      break
    }

    case ArkType.SiloManagedVaultArk: {
      deployedArk = await deploySiloManagedVaultArk(config)
      break
    }
    case ArkType.ArmArk: {
      deployedArk = await deployArmArk(config)
      break
    }

    case ArkType.CrossChainArk: {
      deployedArk = await deployCrossChainArk(config)
      break
    }

    case ArkType.StargateV2PoolArk: {
      deployedArk = await deployStargateV2PoolArk(config)
      break
    }

    case ArkType.SiUSDArk: {
      deployedArk = await deploySiUSDArk(config)
      break
    }

    case ArkType.FluidFTokenArk: {
      deployedArk = await deployFluidFTokenArk(config)
      break
    }
    case ArkType.FluidLiteArk: {
      deployedArk = await deployFluidLiteArk(config)
      break
    }
    case ArkType.PsmLiteERC4626Ark: {
      deployedArk = await deployPsmERC4626Ark(config)
      break
    }

    case ArkType.Psm3ERC4626Ark: {
      deployedArk = await deployPsmERC4626Ark(config)
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
