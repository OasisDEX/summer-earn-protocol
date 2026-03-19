import hre from 'hardhat'
import kleur from 'kleur'
import { createWisdomTreeArkModule } from '../../ignition/modules/arks/wisdom-tree-ark'
import { BaseConfig } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { getChainId } from '../helpers/get-chainid'
import { validateArkDetails } from '../helpers/validation'

export type WisdomTreeArkParams = BaseArkParams & {
  targetWallet: string
  shareToken: string
  oracle: string
  fundName: string
  arkType?: number
  sweepSlippage?: string
}

export async function deployWisdomTreeArk(config: BaseConfig, params: WisdomTreeArkParams) {
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
    arkType,
  } = params
  const chainId = getChainId()
  const envLabel = isBummer ? 'staging_' : ''
  const arkName = `WisdomTree-${fundName}-${token.symbol}-${chainId}`
  const moduleName = `${envLabel}${fleetName}_${arkName.replace(/-/g, '_')}`
  const protocol = 'WisdomTree'

  const arkModule = createWisdomTreeArkModule(moduleName)

  // Create and validate ark details

  const arkDetails = {
    protocol: protocol,
    type: 'WisdomTree',
    asset: token.address,
    marketAsset: token.address,
    pool: shareToken,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'WisdomTree ark details')

  const assetsForwarder = config.deployedContracts.core.assetsForwarder?.address
  if (!assetsForwarder) {
    throw new Error('AssetsForwarder address missing from configuration')
  }

  console.log(
    kleur.cyan(`      Deploying WisdomTreeArk for ${token.symbol} - ${fundName}: ${arkName}`),
  )
  const { ark } = await hre.ignition.deploy(arkModule, {
    parameters: {
      [moduleName]: {
        targetWallet,
        shareToken,
        oracle,
        assetsForwarder,
        arkType: arkType ?? 0,
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

  console.log(kleur.green(`      WisdomTreeArk deployed to: ${ark.address}`))

  return { ark: { address: ark.address } }
}
