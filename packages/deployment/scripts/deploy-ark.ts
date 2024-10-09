import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { deployAaveV3Ark } from './arks/deploy-aavev3-ark'
import { deployCompoundV3Ark } from './arks/deploy-compoundv3-ark'
import { deployERC4626Ark } from './arks/deploy-erc4626-ark'
import { deployMetaMorphoArk } from './arks/deploy-metamorpho-ark'
import { deployMorphoArk } from './arks/deploy-morpho-ark'
import { deployPendleLPArk } from './arks/deploy-pendle-lp-ark'
import { deployPendlePTArk } from './arks/deploy-pendle-pt-ark'
import { addArkToFleet } from './common/add-ark-to-fleet'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'

const arkTypes = [
  { title: 'AaveV3Ark', value: deployAaveV3Ark },
  { title: 'MorphoArk', value: deployMorphoArk },
  { title: 'MetaMorphoArk', value: deployMetaMorphoArk },
  { title: 'CompoundV3Ark', value: deployCompoundV3Ark },
  { title: 'ERC4626Ark', value: deployERC4626Ark },
  { title: 'PendleLPArk', value: deployPendleLPArk },
  { title: 'PendlePTArk', value: deployPendlePTArk },
]

async function deployArk() {
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

  const deployedArk = await selectedArkType(config)

  if (deployedArk) {
    console.log(kleur.green().bold('Ark deployment completed successfully!'))

    // Log the deployed Ark
    ModuleLogger.logArk(deployedArk)

    // Add Ark to Fleet
    await addArkToFleet(deployedArk.ark.address as Address, config, hre)
  } else {
    console.log(kleur.red().bold('Ark deployment failed or was cancelled.'))
  }
}

export type ArkContracts = {
  ark: {
    address: Address
  }
}
// Execute the deployArk function and handle any errors
deployArk().catch((error) => {
  console.error(kleur.red('Error during Ark deployment:'))
  console.error(error)
  process.exit(1)
})
