import { Address } from 'viem'
import { BaseConfig, Token } from '../../types/config-types'
import { deployAaveV3Ark } from '../arks/deploy-aavev3-ark'
import { deployCompoundV3Ark } from '../arks/deploy-compoundv3-ark'
import { deployERC4626Ark } from '../arks/deploy-erc4626-ark'
import { deployMorphoArk, MorphoArkUserInput } from '../arks/deploy-morpho-ark'
import { deployMorphoVaultArk, MorphoVaultArkUserInput } from '../arks/deploy-morpho-vault-ark'
import { deploySkyUsdsArk, SkyUsdsArkUserInput } from '../arks/deploy-sky-usds-ark'
import { deploySkyUsdsPsm3Ark, SkyUsdsPsm3ArkUserInput } from '../arks/deploy-sky-usds-psm3-ark'
import { MAX_UINT256_STRING } from './constants'

export type ArkConfig = {
  type: string
  params: {
    asset: string
    vaultName?: string
  }
}

export async function deployArk(
  arkConfig: ArkConfig,
  config: BaseConfig,
  depositCap: string = MAX_UINT256_STRING,
): Promise<Address> {
  const arkParams = {
    token: {
      address: config.tokens[arkConfig.params.asset.toLowerCase() as Token],
      symbol: arkConfig.params.asset.toLowerCase() as Token,
    },
    depositCap,
    maxRebalanceOutflow: MAX_UINT256_STRING,
    maxRebalanceInflow: MAX_UINT256_STRING,
  }

  let deployedArk

  switch (arkConfig.type) {
    case 'AaveV3Ark':
      deployedArk = await deployAaveV3Ark(config, arkParams)
      break

    case 'CompoundV3Ark':
      deployedArk = await deployCompoundV3Ark(config, arkParams)
      break

    case 'ERC4626Ark':
      if (!arkConfig.params.vaultName) {
        throw new Error('Vault name is required for ERC4626Ark')
      }
      deployedArk = await deployERC4626Ark(config, {
        ...arkParams,
        vaultId:
          config.protocolSpecific.erc4626[arkConfig.params.asset.toLowerCase() as Token][
            arkConfig.params.vaultName
          ],
        vaultName: arkConfig.params.vaultName,
      })
      break

    case 'MorphoArk': {
      const morphoParams: MorphoArkUserInput = {
        ...arkParams,
        marketId:
          config.protocolSpecific.morpho.markets[arkConfig.params.asset.toLowerCase() as Token][
            arkConfig.params.vaultName!
          ],
        // todo: validate
        marketName: arkConfig.params.vaultName!,
      }
      deployedArk = await deployMorphoArk(config, morphoParams)
      break
    }

    case 'MorphoVaultArk': {
      const morphoVaultParams: MorphoVaultArkUserInput = {
        ...arkParams,
        vaultId:
          config.protocolSpecific.morpho.vaults[arkConfig.params.asset.toLowerCase() as Token][
            arkConfig.params.vaultName!
          ],
        vaultName: arkConfig.params.vaultName!,
      }
      deployedArk = await deployMorphoVaultArk(config, morphoVaultParams)
      break
    }

    // case 'PendleLPArk': {
    //   const pendleLPParams = {
    //     ...arkParams,
    //     pendleMarket: config.protocolSpecific.pendle.markets[arkConfig.params.asset.toLowerCase() as Token]
    //   }
    //   deployedArk = await deployPendleLPArk(config, pendleLPParams)
    //   break
    // }

    // case 'PendlePTArk': {
    //   const pendlePTParams = {
    //     ...arkParams,
    //     pendlePT: config.protocolSpecific.pendle.pts[arkConfig.params.asset.toLowerCase() as Token]
    //   }
    //   deployedArk = await deployPendlePTArk(config, pendlePTParams)
    //   break
    // }

    // case 'PendlePtOracleArk': {
    //   const pendlePTOracleParams = {
    //     ...arkParams,
    //     pendleMarket: config.protocolSpecific.pendle.markets[arkConfig.params.asset.toLowerCase() as Token],
    //     pendleOracle: config.protocolSpecific.pendle.oracle
    //   }
    //   deployedArk = await deployPendlePTOracleArk(config, pendlePTOracleParams)
    //   break
    // }

    case 'SkyUsdsArk': {
      const skyUsdsParams: SkyUsdsArkUserInput = {
        ...arkParams,
      }
      deployedArk = await deploySkyUsdsArk(config, skyUsdsParams)
      break
    }

    case 'SkyUsdsPsm3Ark': {
      const skyUsdsPsm3Params: SkyUsdsPsm3ArkUserInput = {
        ...arkParams,
      }
      deployedArk = await deploySkyUsdsPsm3Ark(config, skyUsdsPsm3Params)
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
