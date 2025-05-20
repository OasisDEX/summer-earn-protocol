import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { ArkType, BaseConfig, arkTypes } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { deployArkInteractive } from './common/ark-deployment'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'

async function deployArk() {
  console.log(kleur.green().bold('Starting Ark deployment process...'))

  const { useBummerConfig } = await prompts({
    type: 'confirm',
    name: 'useBummerConfig',
    message: 'Do you want to use the bummer config?',
    initial: false,
  })

  const config = getConfigByNetwork(
    hre.network.name,
    {
      common: true,
      gov: true,
      core: true,
    },
    useBummerConfig,
  ) as BaseConfig

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

    // For regular arks, add to fleet
    if (selectedArkType !== ArkType.CrossChainArk) {
      await addArkToFleet(arkAddress, config, hre)
    } else {
      console.log(kleur.yellow().bold('IMPORTANT: Final step required!'))
      console.log(kleur.cyan('To complete the cross-chain deployment:'))
      console.log(kleur.cyan('1. Switch to the satellite chain network'))
      console.log(
        kleur.cyan(
          '2. Run: npx hardhat run scripts/arks/update-fleet-proxy.ts --network <satellite-chain>',
        ),
      )
    }
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
