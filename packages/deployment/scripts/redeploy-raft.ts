import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { createRaftModule } from '../ignition/modules/raftModuleFactory'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'
import { updateIndexJson } from './helpers/update-json'

export async function redeployRaft() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Check if using Tenderly virtual testnet
  const isTenderly = warnIfTenderlyVirtualTestnet(
    'Deployments on Tenderly virtual testnets are temporary and will be lost when the session ends.',
  )

  if (isTenderly) {
    const response = await prompts({
      type: 'confirm',
      name: 'continue',
      message: 'Do you want to continue with deployment on this Tenderly virtual testnet?',
      initial: false,
    })

    if (!response.continue) {
      console.log(kleur.red('Deployment cancelled.'))
      return
    }
  }

  // Ask about using bummer config
  const useBummerConfig = await promptForConfigType()

  // Load the configuration for the current network
  const config = getConfigByNetwork(
    network,
    { common: true, core: true, gov: true },
    useBummerConfig,
  )

  // Display summary and get confirmation
  if (!(await confirmDeployment(network))) {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }

  console.log(kleur.cyan().bold('Redeploying Raft...'))

  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const timestampString = new Date().toISOString().replace(/[-:Z.]/g, '')
  const moduleName = `RaftModule_${timestampString}`
  const RaftModule = createRaftModule(moduleName)

  const result = await hre.ignition.deploy(RaftModule, {
    parameters: {
      [moduleName]: {
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
      },
    },
    deploymentId,
  })

  console.log(kleur.green().bold('Raft Redeployed Successfully!'))

  // Update just the raft address in the core config
  const coreContracts = {
    ...config.deployedContracts.core,
    raft: result.raft,
  }
  updateIndexJson('core', network, coreContracts, useBummerConfig)

  return result
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {string} network - The network being deployed to.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(network: string): Promise<boolean> {
  console.log(kleur.yellow(`Raft will be redeployed on: ${network}`))
  return await continueDeploymentCheck()
}

redeployRaft().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
