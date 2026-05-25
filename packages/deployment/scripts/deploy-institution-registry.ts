import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import {
  InstitutionRegistryContracts,
  createInstitutionRegistryModule,
} from '../ignition/modules/institution-registry'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

async function main() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(
    hre.network.name,
    { common: true, gov: false, core: false },
    useBummerConfig,
  )

  const { owner } = await prompts({
    type: 'text',
    name: 'owner',
    message: 'Enter owner (EOA or multisig) address for InstitutionalVaultRegistry V2:',
    initial: (await hre.viem.getWalletClients())[0]?.account.address,
    validate: (v) => (/^0x[a-fA-F0-9]{40}$/.test(v) ? true : 'Invalid address'),
  })

  console.log(kleur.cyan().bold('Deploying InstitutionalVaultRegistry (v2)...'))
  const envLabel = useBummerConfig ? 'staging_' : ''
  const moduleName = `${envLabel}InstitutionRegistryV2`
  const RegistryModule = createInstitutionRegistryModule(moduleName)
  const deployed = (await hre.ignition.deploy(RegistryModule, {
    parameters: { [moduleName]: { owner } },
  })) as InstitutionRegistryContracts

  console.log(
    kleur.green().bold('InstitutionalVaultRegistry V2 deployed at:'),
    deployed.institutionalVaultRegistry.address,
  )

  // Update the main index.json only (one v2 registry per network)
  await updateIndexJson(
    'core',
    hre.network.name,
    {
      ...(config as BaseConfig).deployedContracts.core,
      institutionalVaultRegistryV2: { address: deployed.institutionalVaultRegistry.address },
    } as any,
    useBummerConfig,
  )
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
