import hre from 'hardhat'
import kleur from 'kleur'
import { createDaoTipJarModule, DaoTipJarContracts } from '../ignition/modules/dao-tip-jar'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'
import { keccak256, toBytes } from 'viem'

async function main() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(
    hre.network.name,
    { common: true, gov: false, core: true },
    useBummerConfig,
  ) as BaseConfig

  const accessManager = config.deployedContracts.gov.protocolAccessManager.address
  const configurationManager = config.deployedContracts.core.configurationManager.address
  const CREATE2_SALT = keccak256(toBytes('daoTipJar'))
  console.log(kleur.cyan().bold('Deploying DaoTipJar...'))
  const envLabel = useBummerConfig ? 'staging_' : ''
  const moduleName = `${envLabel}DaoTipJar`
  const DaoTipJarModule = createDaoTipJarModule(moduleName)
  const deployed = (await hre.ignition.deploy(DaoTipJarModule, {
    parameters: {
      [moduleName]: { accessManager, configurationManager },
    },
    strategy: 'create2',
    strategyConfig: {
      salt: CREATE2_SALT,
    },
  })) as DaoTipJarContracts

  console.log(kleur.green().bold('DaoTipJar deployed at:'), deployed.daoTipJar.address)

  await updateIndexJson(
    'core',
    hre.network.name,
    {
      ...(config.deployedContracts.core as Record<string, unknown>),
      daoTipJar: { address: deployed.daoTipJar.address },
    } as Parameters<typeof updateIndexJson>[2],
    useBummerConfig,
  )
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
