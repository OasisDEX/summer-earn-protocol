import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { ArkType } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { deployArkInteractive } from './common/ark-deployment'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'

const arkTypes = [
  { title: 'AaveV3Ark', value: ArkType.AaveV3Ark },
  { title: 'SparkArk', value: ArkType.SparkArk },
  { title: 'MorphoArk', value: ArkType.MorphoArk },
  { title: 'MorphoVaultArk', value: ArkType.MorphoVaultArk },
  { title: 'CompoundV3Ark', value: ArkType.CompoundV3Ark },
  { title: 'ERC4626Ark', value: ArkType.ERC4626Ark },
  { title: 'SkyUsdsArk', value: ArkType.SkyUsdsArk },
  { title: 'SkyUsdsPsm3Ark', value: ArkType.SkyUsdsPsm3Ark },
  { title: 'PendleLPArk', value: ArkType.PendleLPArk },
  { title: 'PendlePTArk', value: ArkType.PendlePTArk },
  { title: 'PendlePtOracleArk', value: ArkType.PendlePtOracleArk },
]

async function deployArk() {
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: true, core: true })

  console.log(kleur.green().bold('Starting Ark deployment process...'))

  const { selectedArkType } = await prompts({
    type: 'select',
    name: 'selectedArkType',
    message: 'Select the type of Ark to deploy:',
    choices: arkTypes,
  })

  if (!selectedArkType) {
    console.log(kleur.red().bold('No Ark type selected. Exiting.'))
    return
  }

  try {
    const arkAddress = await deployArkInteractive(selectedArkType, config)
    console.log(kleur.green().bold('Ark deployment completed successfully!'))

    ModuleLogger.logArk({ ark: { address: arkAddress } })

    await addArkToFleet(arkAddress, config, hre)
  } catch (error) {
    console.log(kleur.red().bold('Ark deployment failed or was cancelled.'))
    throw error
  }
}

deployArk().catch((error) => {
  console.error(kleur.red('Error during Ark deployment:'))
  console.error(error)
  process.exit(1)
})
