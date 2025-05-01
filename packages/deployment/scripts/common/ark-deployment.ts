import { Address } from 'viem'
import { ArkType, BaseConfig, FleetConfig, Token } from '../../types/config-types'
import { deployAaveV3Ark } from '../arks/deploy-aavev3-ark'
import { deployCompoundV3Ark } from '../arks/deploy-compoundv3-ark'
import { ERC4626ArkUserInput, deployERC4626Ark } from '../arks/deploy-erc4626-ark'
import { deployFluidLiteArk } from '../arks/deploy-fluid-lite-ark'
import { deployMoonwellArk } from '../arks/deploy-moonwell-ark'
import { MorphoArkUserInput, deployMorphoArk } from '../arks/deploy-morpho-ark'
import { MorphoVaultArkUserInput, deployMorphoVaultArk } from '../arks/deploy-morpho-vault-ark'
import { deployOriginETHArk } from '../arks/deploy-origineth-ark'
import { PendleLPArkUserInput, deployPendleLPArk } from '../arks/deploy-pendle-lp-ark'
import { PendlePTArkUserInput, deployPendlePTArk } from '../arks/deploy-pendle-pt-ark'
import {
  PendlePtOracleArkUserInput,
  deployPendlePTOracleArk,
} from '../arks/deploy-pendle-pt-oracle-ark'
import { SiloArkUserInput, deploySiloArk } from '../arks/deploy-silo-ark'
import { deploySkyRewardsArk } from '../arks/deploy-sky-rewards-ark'
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
    protocol: string
    vaultName?: string // For ERC4626Ark
    depositCap?: string // For FluidLiteArk
    maxRebalanceOutflow?: string // For FluidLiteArk
    maxRebalanceInflow?: string // For FluidLiteArk
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
  marketId?: string
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
    depositCap: params.depositCap || MAX_UINT256_STRING,
    maxRebalanceOutflow: params.maxRebalanceOutflow || MAX_UINT256_STRING,
    maxRebalanceInflow: params.maxRebalanceInflow || MAX_UINT256_STRING,
    fleetName: fleetConfig.fleetName,
  }
  console.log('Base Ark Params [Debug]:', baseArkParams)

  let deployedArk

  switch (type) {
    case ArkType.FluidLiteArk: {
      const wrapper = config.protocolSpecific.fluid.lite[token].wrapper
      const vault = config.protocolSpecific.fluid.lite[token].vault
      const withdrawalQueue = config.protocolSpecific.fluid.lite[token].withdrawalQueue

      validateAddress(wrapper, 'FluidLite wrapper')
      validateAddress(vault, 'FluidLite vault')
      validateAddress(withdrawalQueue, 'FluidLite withdrawal queue')

      console.log('FluidLiteArk params:')
      console.log(baseArkParams)

      const ark = await deployFluidLiteArk(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.AaveV3Ark: {
      const marketId = validateMarketId(protocol, 'AaveV3 market ID')
      const ark = await deployAaveV3Ark(config, {
        ...baseArkParams,
        marketId,
      })
      deployedArk = ark
      break
    }
    case ArkType.SparkArk: {
      const marketId = validateMarketId(protocol, 'Spark market ID')
      const ark = await deploySparkArk(config, {
        ...baseArkParams,
        marketId,
      })
      deployedArk = ark
      break
    }
    case ArkType.CompoundV3Ark: {
      const marketId = validateMarketId(protocol, 'CompoundV3 market ID')
      const ark = await deployCompoundV3Ark(config, {
        ...baseArkParams,
        marketId,
      })
      deployedArk = ark
      break
    }
    case ArkType.ERC4626Ark: {
      const validatedVaultName = validateString(vaultName, 'vault name')
      const vaultAddress = validateErc4626Address(
        config.protocolSpecific.erc4626[token][validatedVaultName],
        'ERC4626 vault',
      )
      const ark = await deployERC4626Ark(config, {
        ...baseArkParams,
        vaultId: vaultAddress,
        vaultName: validatedVaultName,
      } as ERC4626ArkUserInput)
      deployedArk = ark
      break
    }
    case ArkType.MorphoArk: {
      const marketId = validateMarketId(protocol, 'Morpho market ID')
      const ark = await deployMorphoArk(config, {
        ...baseArkParams,
        marketId,
      } as MorphoArkUserInput)
      deployedArk = ark
      break
    }
    case ArkType.MorphoVaultArk: {
      const marketId = validateMarketId(protocol, 'Morpho vault market ID')
      const ark = await deployMorphoVaultArk(config, {
        ...baseArkParams,
        marketId,
        vaultId: marketId,
        vaultName: protocol,
      } as MorphoVaultArkUserInput)
      deployedArk = ark
      break
    }
    case ArkType.PendleLPArk: {
      const marketId = validateMarketId(protocol, 'Pendle LP market ID')
      const ark = await deployPendleLPArk(config, {
        ...baseArkParams,
        marketId,
        marketName: protocol,
      } as PendleLPArkUserInput)
      deployedArk = ark
      break
    }
    case ArkType.PendlePTArk: {
      const marketId = validateMarketId(protocol, 'Pendle PT market ID')
      const ark = await deployPendlePTArk(config, {
        ...baseArkParams,
        marketId,
        marketName: protocol,
      } as PendlePTArkUserInput)
      deployedArk = ark
      break
    }
    case ArkType.PendlePtOracleArk: {
      const marketId = validateMarketId(protocol, 'Pendle PT Oracle market ID')
      const ark = await deployPendlePTOracleArk(config, {
        ...baseArkParams,
        marketId,
        marketName: protocol,
      } as PendlePtOracleArkUserInput)
      deployedArk = ark
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
      const marketId = validateMarketId(protocol, 'Moonwell market ID')
      const ark = await deployMoonwellArk(config, {
        ...baseArkParams,
        marketId,
      })
      deployedArk = ark
      break
    }
    case ArkType.SyrupArk: {
      const marketId = validateMarketId(protocol, 'Syrup market ID')
      const ark = await deploySyrupArk(config, {
        ...baseArkParams,
        marketId,
      })
      deployedArk = ark
      break
    }
    case ArkType.SkyRewardsArk: {
      const ark = await deploySkyRewardsArk(config, baseArkParams)
      deployedArk = ark
      break
    }
    case ArkType.SiloArk: {
      const marketId = validateMarketId(protocol, 'Silo market ID')
      const ark = await deploySiloArk(config, {
        ...baseArkParams,
        siloId: marketId,
        siloName: protocol,
      } as SiloArkUserInput)
      deployedArk = ark
      break
    }
    case ArkType.OriginETHArk: {
      const ark = await deployOriginETHArk(config, baseArkParams)
      deployedArk = ark
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
  let deployedArk
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
