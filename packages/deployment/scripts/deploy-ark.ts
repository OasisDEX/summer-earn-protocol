import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { ArkType, BaseConfig, arkTypes } from '../types/config-types'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { deployArkInteractive } from './common/ark-deployment'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'

async function deployArk() {
  const config = getConfigByNetwork(hre.network.name, {
    common: true,
    gov: true,
    core: true,
  }) as BaseConfig

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

  // Special handling for CrossChainArk type which requires a different workflow
  if (selectedArkType === ArkType.CrossChainArk) {
    console.log(
      kleur
        .yellow()
        .bold('You selected CrossChainArk which requires a multi-chain deployment process.'),
    )
    console.log(
      kleur.cyan('This is a special type of Ark that involves deployment on two different chains:'),
    )
    console.log(kleur.cyan('1. FleetProxy on the satellite chain'))
    console.log(kleur.cyan('2. CrossChainArk on the source chain (current chain)'))
    console.log(kleur.cyan('3. Update FleetProxy with the CrossChainArk address'))

    const { confirmed } = await prompts({
      type: 'confirm',
      name: 'confirmed',
      message: 'Have you already deployed the FleetProxy on the satellite chain?',
      initial: false,
    })

    if (!confirmed) {
      console.log(kleur.yellow('Please follow these steps:'))
      console.log(kleur.cyan('1. Switch to the satellite chain network'))
      console.log(
        kleur.cyan(
          '2. Run: npx hardhat run scripts/arks/deploy-fleet-proxy.ts --network <satellite-chain>',
        ),
      )
      console.log(kleur.cyan('3. Come back to this chain and run this script again'))
      return
    }
  }

  try {
    const arkAddress = await deployArkInteractive(selectedArkType, config)
    console.log(kleur.green().bold('Ark deployment completed successfully!'))

    ModuleLogger.logArk({ ark: { address: arkAddress } })

    // For CrossChainArk, remind about updating FleetProxy
    if (selectedArkType === ArkType.CrossChainArk) {
      console.log(kleur.yellow().bold('IMPORTANT: Final step required!'))
      console.log(kleur.cyan('To complete the cross-chain deployment:'))
      console.log(kleur.cyan('1. Switch to the satellite chain network'))
      console.log(
        kleur.cyan(
          '2. Run: npx hardhat run scripts/arks/update-fleet-proxy.ts --network <satellite-chain>',
        ),
      )
    } else {
      // For regular arks, add to fleet
      await addArkToFleet(arkAddress, config, hre)
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
