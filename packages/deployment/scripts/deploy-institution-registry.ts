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
    message: 'Enter owner (EOA or multisig) address for InstitutionalVaultRegistry:',
    initial: (await hre.viem.getWalletClients())[0]?.account.address,
    validate: (v) => (/^0x[a-fA-F0-9]{40}$/.test(v) ? true : 'Invalid address'),
  })

  console.log(kleur.cyan().bold('Deploying InstitutionalVaultRegistry...'))
  const envLabel = useBummerConfig ? 'staging_' : ''
  const moduleName = `${envLabel}InstitutionRegistry`
  const RegistryModule = createInstitutionRegistryModule(moduleName)
  const deployed = (await hre.ignition.deploy(RegistryModule, {
    parameters: { [moduleName]: { owner } },
  })) as InstitutionRegistryContracts

  console.log(
    kleur.green().bold('InstitutionalVaultRegistry deployed at:'),
    deployed.institutionalVaultRegistry.address,
  )

  // Update the main index.json only (one registry per network)
  await updateIndexJson(
    'core',
    hre.network.name,
    {
      ...(config as BaseConfig).deployedContracts.core,
      institutionalVaultRegistry: { address: deployed.institutionalVaultRegistry.address },
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
