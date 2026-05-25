import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createRoundsVaultRegistryModule } from '../ignition/modules/rounds/rounds-vault-registry'
import { BaseConfig } from '../types/config-types'
import { ADDRESS_ZERO } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

async function main() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(
    hre.network.name,
    { common: true, gov: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  const pamAddress = config.deployedContracts.gov.protocolAccessManager?.address
  if (!pamAddress || pamAddress === ADDRESS_ZERO) {
    console.log(
      kleur.red(
        'ProtocolAccessManager address missing from gov config — deploy it before the registry.',
      ),
    )
    return
  }

  const { accessManager } = await prompts({
    type: 'text',
    name: 'accessManager',
    message: 'Enter ProtocolAccessManager address that will govern RoundsVaultRegistry:',
    initial: pamAddress,
    validate: (v) => (/^0x[a-fA-F0-9]{40}$/.test(v) ? true : 'Invalid address'),
  })

  const envLabel = useBummerConfig ? 'staging_' : ''
  const moduleName = `${envLabel}RoundsVaultRegistry`

  console.log(kleur.cyan().bold('Deploying RoundsVaultRegistry...'))
  const RegistryModule = createRoundsVaultRegistryModule(moduleName)
  const deployed = (await hre.ignition.deploy(RegistryModule, {
    parameters: { [moduleName]: { accessManager } },
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
