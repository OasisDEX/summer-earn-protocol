import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address as ViemAddress } from 'viem'
import {
  InstitutionWhitelistContracts,
  InstitutionWhitelistModule,
} from '../ignition/modules/institution-whitelist'
import { getConfigByNetwork } from './helpers/config-handler'
import { updateInstitutionDeployedContracts } from './helpers/institution-config'
import { promptForConfigType } from './helpers/prompt-helpers'
import { AddressSchema } from './helpers/zod-schemas'

async function main() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  const useBummerConfig = await promptForConfigType()

  const { institutionId } = await prompts({
    type: 'text',
    name: 'institutionId',
    message: 'Enter institution id (folder name under config/institutions):',
    validate: (v) => (v && /^[A-Za-z0-9_-]+$/.test(v) ? true : 'Invalid id'),
  })

  if (!institutionId) {
    console.log(kleur.red('No institution id provided. Exiting.'))
    return
  }

  const config = getConfigByNetwork(
    hre.network.name,
    { common: true, gov: false, core: false },
    useBummerConfig,
  )

  console.log(kleur.cyan().bold('Deploying Institution Whitelist...'))
  // Prompt for treasury (institution-specific) and validate with Zod Address
  const { treasury } = await prompts({
    type: 'text',
    name: 'treasury',
    message: 'Enter treasury address for this institution:',
    validate: (v) => (AddressSchema.safeParse(v).success ? true : 'Invalid address'),
  })

  const deployed = (await hre.ignition.deploy(InstitutionWhitelistModule, {
    parameters: {
      InstitutionWhitelistModule: {
        swapProvider: config.common.swapProvider,
        weth: config.tokens.weth,
        treasury: treasury as ViemAddress,
      },
    },
  })) as InstitutionWhitelistContracts

  console.log(kleur.green().bold('Institution contracts deployed. Writing institution index...'))

  // gov: only protocolAccessManager for whitelist flow
  updateInstitutionDeployedContracts(institutionId, useBummerConfig, hre.network.name, 'gov', {
    protocolAccessManager: { address: deployed.protocolAccessManager.address },
  })

  // core subset
  updateInstitutionDeployedContracts(institutionId, useBummerConfig, hre.network.name, 'core', {
    tipJar: { address: deployed.tipJar.address },
    configurationManager: { address: deployed.configurationManager.address },
    harborCommand: { address: deployed.harborCommand.address },
    admiralsQuarters: { address: deployed.admiralsQuarters.address },
    raft: { address: deployed.raft.address },
  })

  console.log(kleur.green().bold('Institution index updated successfully.'))
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
