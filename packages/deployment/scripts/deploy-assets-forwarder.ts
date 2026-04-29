import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { createAssetsForwarderModule } from '../ignition/modules/utils/assets-forwarder'

async function deployAssetsForwarder() {
  console.log(kleur.green().bold('Starting AssetsForwarder deployment...'))

  // Ask for the necessary parameters
  const response = await prompts({
    type: 'text',
    name: 'accessManager',
    message: 'Enter the AccessManager address: ',
    validate: (input: string) =>
      input.startsWith('0x') && input.length === 42
        ? true
        : 'Invalid address format. Needs to be a valid 42-character hex string starting with 0x.',
  })

  const accessManager = response.accessManager
  if (!accessManager) {
    console.log(kleur.red('Deployment cancelled. AccessManager address is required.'))
    return
  }

  const args = {
    accessManager,
  }

  try {
    const assetsForwarderModule = createAssetsForwarderModule('AssetsForwarderModule')

    const deployedAddress = await hre.ignition.deploy(assetsForwarderModule, {
      parameters: { AssetsForwarderModule: args },
    })

    console.log(kleur.green().bold('AssetsForwarder deployment completed successfully!'))
    console.log(`- AssetsForwarder: ${deployedAddress.assetsForwarder.address}`)

    return deployedAddress
  } catch (error) {
    console.error(kleur.red('Error during AssetsForwarder deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    throw error
  }
}

// Execute the deployAssetsForwarder function and handle any errors
if (require.main === module) {
  deployAssetsForwarder().catch((error) => {
    console.error(kleur.red('Error during AssetsForwarder deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { deployAssetsForwarder }
