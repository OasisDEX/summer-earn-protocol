import hre from 'hardhat'
import kleur from 'kleur'
import {
  createSuperstateArkModule,
  SuperstateArkVariant,
} from '../../ignition/modules/arks/superstate-ark'
import { BaseConfig } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { getChainId } from '../helpers/get-chainid'
import { validateArkDetails } from '../helpers/validation'

export type SuperstateArkParams = BaseArkParams & {
  // 'subscribe' → SuperstateSubscribeArk (uses superstateRedeem); 'standard' → SuperstateStandardArk.
  variant: SuperstateArkVariant
  shareToken: string
  superstateSubscribe: string
  // Required for the 'subscribe' variant; ignored for 'standard'.
  superstateRedeem?: string
  oracle: string
  fundName: string
  sweepSlippage: string
  depositSlippage: string
}

export async function deploySuperstateArk(config: BaseConfig, params: SuperstateArkParams) {
  const {
    token,
    depositCap,
    maxRebalanceOutflow,
    maxRebalanceInflow,
    maxDepositPercentageOfTVL,
    fleetName,
    isBummer,
    variant,
    shareToken,
    superstateSubscribe,
    superstateRedeem,
    oracle,
    fundName,
    sweepSlippage,
    depositSlippage,
  } = params
  const chainId = getChainId()
  const envLabel = isBummer ? 'staging_' : ''
  const arkName = `Superstate-${fundName}-${token.symbol}-${chainId}`
  const moduleName = `${envLabel}${fleetName}_${arkName.replace(/-/g, '_')}`
  const protocol = 'Superstate'

  if (variant === 'subscribe' && !superstateRedeem) {
    throw new Error(
      `Superstate fund '${fundName}' is a 'subscribe' ark but no superstateRedeem address was provided`,
    )
  }

  const arkModule = createSuperstateArkModule(moduleName, variant)

  // Create and validate ark details

  const arkDetails = {
    protocol: protocol,
    type: 'Superstate',
    asset: token.address,
    marketAsset: token.address,
    pool: shareToken,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'Superstate ark details')

  console.log(
    kleur.cyan(`      Deploying SuperstateArk for ${token.symbol} - ${fundName}: ${arkName}`),
  )
  const { ark } = await hre.ignition.deploy(arkModule, {
    parameters: {
      [moduleName]: {
        shareToken,
        superstateSubscribe,
        // Only the 'subscribe' module reads superstateRedeem; omit it otherwise.
        ...(variant === 'subscribe' ? { superstateRedeem } : {}),
        oracle,
        sweepSlippage: sweepSlippage ?? '0',
        depositSlippage: depositSlippage ?? '0',
        name: arkName,
        details: JSON.stringify(arkDetails),
        configurationManager: config.deployedContracts.core.configurationManager.address,
        accessManager: config.deployedContracts.gov.protocolAccessManager.address,
        asset: token.address,
        depositCap: depositCap,
        maxRebalanceOutflow: maxRebalanceOutflow,
        maxRebalanceInflow: maxRebalanceInflow,
        requiresKeeperData: false,
        maxDepositPercentageOfTVL: maxDepositPercentageOfTVL,
      },
    },
  })

  console.log(kleur.green(`      SuperstateArk deployed to: ${(ark as any).address}`))

  return { ark: { address: (ark as any).address } }
}
