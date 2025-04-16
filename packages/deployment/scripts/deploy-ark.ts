import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { arkTypes } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { deployArkInteractive } from './common/ark-deployment'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'

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
