import hre from 'hardhat'
import kleur from 'kleur'
import { createWisdomTreeArkModule } from '../../ignition/modules/arks/wisdom-tree-ark'
import { BaseConfig } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'

export type WisdomTreeArkParams = BaseArkParams & {
  targetWallet: string
  shareToken: string
  oracle: string
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
  } = params

  const envLabel = isBummer ? 'staging_' : ''
  const name = fleetName ? fleetName.replace(/\W/g, '') : ''
  const moduleName = `${envLabel}WisdomTreeArk_${name}`

  const arkModule = createWisdomTreeArkModule(moduleName)

  console.log(kleur.cyan(`      Deploying WisdomTreeArk for ${token.symbol}`))
  const { ark } = await hre.ignition.deploy(arkModule, {
    parameters: {
      [moduleName]: {
        targetWallet,
        shareToken,
        oracle,
        name: `WisdomTree Ark ${token.symbol}`,
        details: 'WisdomTree Ark',
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
