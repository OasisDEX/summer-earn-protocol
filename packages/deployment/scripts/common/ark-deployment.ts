import { Address } from 'viem'
import { ArkType, BaseConfig, FleetConfig, Token } from '../../types/config-types'
import { deployAaveV3Ark } from '../arks/deploy-aavev3-ark'
import { deployCompoundV3Ark } from '../arks/deploy-compoundv3-ark'
import { deployERC4626Ark } from '../arks/deploy-erc4626-ark'
import { deployMoonwellArk } from '../arks/deploy-moonwell-ark'
import { MorphoArkUserInput, deployMorphoArk } from '../arks/deploy-morpho-ark'
import { MorphoVaultArkUserInput, deployMorphoVaultArk } from '../arks/deploy-morpho-vault-ark'
import { deployPendleLPArk } from '../arks/deploy-pendle-lp-ark'
import { deployPendlePTArk } from '../arks/deploy-pendle-pt-ark'
import { deployPendlePTOracleArk } from '../arks/deploy-pendle-pt-oracle-ark'
import { deploySiloArk } from '../arks/deploy-silo-ark'
import { deploySkyUsdsArk } from '../arks/deploy-sky-usds-ark'
import { deploySkyUsdsPsm3Ark } from '../arks/deploy-sky-usds-psm3-ark'
import { deploySparkArk } from '../arks/deploy-spark-ark'
import { deploySyrupArk } from '../arks/deploy-syrup-ark'
import {
  validateAddress,
  validateErc4626Address,
  validateMarketId,
  validateString,
  validateToken,
} from '../helpers/validation'
import { MAX_UINT256_STRING } from './constants'

export type ArkConfig = {
  type: ArkType
  params: {
    asset: string
    vaultName?: string
  }
}
export type BaseArkParams = {
  token: {
    address: Address
    symbol: Token
  }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  fleetName: string
}

export async function deployArk(
  arkConfig: ArkConfig,
  config: BaseConfig,
  fleetConfig: FleetConfig,
): Promise<Address> {
  const depositCap = '0'
  const token = validateToken(config, arkConfig.params.asset)
  const baseArkParams: BaseArkParams = {
    token: {
      address: config.tokens[token],
      symbol: token,
    },
    depositCap,
    maxRebalanceOutflow: MAX_UINT256_STRING,
    maxRebalanceInflow: MAX_UINT256_STRING,
    fleetName: fleetConfig.fleetName,
  }

  let deployedArk

  switch (arkConfig.type) {
    case ArkType.SyrupArk:
      deployedArk = await deploySyrupArk(config, baseArkParams)
      break
    case ArkType.AaveV3Ark:
      deployedArk = await deployAaveV3Ark(config, baseArkParams)
      break
    case ArkType.SparkArk:
      deployedArk = await deploySparkArk(config, baseArkParams)
      break
    case ArkType.MoonwellArk:
      deployedArk = await deployMoonwellArk(config, baseArkParams)
      break
    case ArkType.CompoundV3Ark:
      deployedArk = await deployCompoundV3Ark(config, baseArkParams)
      break

    case ArkType.ERC4626Ark:
      const erc4626VaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const erc4626VaultId = validateErc4626Address(
        config.protocolSpecific.erc4626[token][erc4626VaultName],
        `ERC4626-${erc4626VaultName}`,
      )
      deployedArk = await deployERC4626Ark(config, {
        ...baseArkParams,
        vaultId: erc4626VaultId,
        vaultName: erc4626VaultName,
      })
      break

    case ArkType.MorphoArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const marketId = validateMarketId(
        config.protocolSpecific.morpho.markets[token][vaultName],
        `Morpho-${vaultName}`,
      )
      const morphoParams: MorphoArkUserInput = {
        ...baseArkParams,
        marketId,
        marketName: vaultName,
      }
      deployedArk = await deployMorphoArk(config, morphoParams)
      break
    }

    case ArkType.MorphoVaultArk: {
      const vaultName = validateString(arkConfig.params.vaultName, 'vaultName')
      const vaultId = validateErc4626Address(
        config.protocolSpecific.morpho.vaults[token][vaultName],
        `Morpho-${vaultName}`,
      )
      const morphoVaultParams: MorphoVaultArkUserInput = {
        ...baseArkParams,
        vaultId,
        vaultName: vaultName,
      }
      deployedArk = await deployMorphoVaultArk(config, morphoVaultParams)
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
      deployedArk = await deploySkyUsdsArk(config, baseArkParams)
      break
    }

    case ArkType.SkyUsdsPsm3Ark: {
      deployedArk = await deploySkyUsdsPsm3Ark(config, baseArkParams)
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

    default:
      throw new Error(`Unknown Ark type: ${arkConfig.type}`)
  }

  if (!deployedArk?.ark?.address) {
    throw new Error(`Failed to deploy ${arkConfig.type}`)
  }

  return deployedArk.ark.address as Address
}

export async function deployArkInteractive(arkType: ArkType, config: BaseConfig) {
  let deployedArk
  switch (arkType) {
    case ArkType.SyrupArk:
      deployedArk = await deploySyrupArk(config)
      break
    case ArkType.AaveV3Ark:
      deployedArk = await deployAaveV3Ark(config)
      break
    case ArkType.SparkArk:
      deployedArk = await deploySparkArk(config)
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

    default:
      throw new Error(`Unknown Ark type: ${arkType}`)
  }

  if (!deployedArk?.ark?.address) {
    throw new Error(`Failed to deploy ${arkType}`)
  }

  return deployedArk.ark.address as Address
}
