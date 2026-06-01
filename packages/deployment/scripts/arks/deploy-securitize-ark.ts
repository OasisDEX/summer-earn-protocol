import hre from 'hardhat'
import kleur from 'kleur'
import { createSecuritizeArkModule } from '../../ignition/modules/arks/securitize-ark'
import { BaseConfig } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { getChainId } from '../helpers/get-chainid'
import { validateArkDetails } from '../helpers/validation'

export type SecuritizeArkParams = BaseArkParams & {
  targetWallet: string
  shareToken: string
  oracle: string
  fundName: string
  sweepSlippage: string
  depositSlippage: string
}

export async function deploySecuritizeArk(config: BaseConfig, params: SecuritizeArkParams) {
  const {
    token,
    depositCap,
    maxRebalanceOutflow,
    maxRebalanceInflow,
    maxDepositPercentageOfTVL,
    fleetName,
    isBummer,
    targetWallet,
    shareToken,
    oracle,
    fundName,
    sweepSlippage,
    depositSlippage,
  } = params
  const chainId = getChainId()
  const envLabel = isBummer ? 'staging_' : ''
  const arkName = `Securitize-${fundName}-${token.symbol}-${chainId}`
  const moduleName = `${envLabel}${fleetName}_${arkName.replace(/-/g, '_')}`
  const protocol = 'Securitize'

  const arkModule = createSecuritizeArkModule(moduleName)

  // Create and validate ark details

  const arkDetails = {
    protocol: protocol,
    type: 'Securitize',
    asset: token.address,
    marketAsset: token.address,
    pool: shareToken,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'Securitize ark details')

  console.log(
    kleur.cyan(`      Deploying SecuritizeArk for ${token.symbol} - ${fundName}: ${arkName}`),
  )
  const { ark } = await hre.ignition.deploy(arkModule, {
    parameters: {
      [moduleName]: {
        targetWallet,
        shareToken,
        oracle,
        sweepSlippage: sweepSlippage ?? 0,
        depositSlippage: depositSlippage ?? 0,
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

  console.log(kleur.green(`      SecuritizeArk deployed to: ${ark.address}`))

  return { ark: { address: ark.address } }
}
