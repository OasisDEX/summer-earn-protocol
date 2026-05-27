import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createRoundsVaultRegistryModule } from '../ignition/modules/rounds/rounds-vault-registry'
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
  ) as BaseConfig

  const { owner } = await prompts({
    type: 'text',
    name: 'owner',
    message: 'Enter owner (EOA or multisig) address for RoundsVaultRegistry:',
    initial: (await hre.viem.getWalletClients())[0]?.account.address,
    validate: (v) => (/^0x[a-fA-F0-9]{40}$/.test(v) ? true : 'Invalid address'),
  })

  const envLabel = useBummerConfig ? 'staging_' : ''
  const moduleName = `${envLabel}RoundsVaultRegistry`

  console.log(kleur.cyan().bold('Deploying RoundsVaultRegistry...'))
  const RegistryModule = createRoundsVaultRegistryModule(moduleName)
  const deployed = (await hre.ignition.deploy(RegistryModule, {
    parameters: { [moduleName]: { owner } },
  })) as { roundsVaultRegistry: { address: Address } }

  console.log(
    kleur.green().bold('RoundsVaultRegistry deployed at:'),
    deployed.roundsVaultRegistry.address,
  )

  await updateIndexJson(
    'core',
    hre.network.name,
    {
      ...(config as BaseConfig).deployedContracts.core,
      roundsVaultRegistry: { address: deployed.roundsVaultRegistry.address },
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
