import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { ArkConfig, deployArk } from './common/ark-deployment'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'

const arkTypes = [
  { title: 'AaveV3Ark', value: 'AaveV3Ark' },
  { title: 'MorphoArk', value: 'MorphoArk' },
  { title: 'MorphoVaultArk', value: 'MorphoVaultArk' },
  { title: 'CompoundV3Ark', value: 'CompoundV3Ark' },
  { title: 'ERC4626Ark', value: 'ERC4626Ark' },
  { title: 'SkyUsdsArk', value: 'SkyUsdsArk' },
  { title: 'SkyUsdsPsm3Ark', value: 'SkyUsdsPsm3Ark' },
  { title: 'PendleLPArk', value: 'PendleLPArk' },
  { title: 'PendlePTArk', value: 'PendlePTArk' },
  { title: 'PendlePtOracleArk', value: 'PendlePtOracleArk' },
  { title: 'SkyUsdsArk', value: 'SkyUsdsArk' },
  { title: 'SkyUsdsPsm3Ark', value: 'SkyUsdsPsm3Ark' },
]

async function deployArkInteractive() {
  const config = getConfigByNetwork(hre.network.name)
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

  const { asset } = await prompts({
    type: 'text',
    name: 'asset',
    message: 'Enter the asset symbol (e.g., USDC):',
  })

  const arkConfig: ArkConfig = {
    type: selectedArkType,
    params: {
      asset: asset.toUpperCase(),
    },
  }

  try {
    const arkAddress = await deployArk(arkConfig, config)
    console.log(kleur.green().bold('Ark deployment completed successfully!'))

    ModuleLogger.logArk({ ark: { address: arkAddress } })

    await addArkToFleet(arkAddress, config, hre)
  } catch (error) {
    console.log(kleur.red().bold('Ark deployment failed or was cancelled.'))
    throw error
  }
}

deployArkInteractive().catch((error) => {
  console.error(kleur.red('Error during Ark deployment:'))
  console.error(error)
  process.exit(1)
})
