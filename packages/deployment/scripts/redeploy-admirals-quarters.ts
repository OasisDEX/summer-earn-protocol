import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { AdmiralsQuartersModule } from '../ignition/modules/admiralsQuarters'
import { BaseConfig } from '../types/config-types'
import { ADMIRALS_QUARTERS_ROLE, GOVERNOR_ROLE } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'
import { updateIndexJson } from './helpers/update-json'

export async function redeployAdmiralsQuarters() {
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

  console.log(kleur.cyan().bold('Redeploying AdmiralsQuarters...'))

  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  const result = await hre.ignition.deploy(AdmiralsQuartersModule, {
    parameters: {
      AdmiralsQuartersModule: {
        swapProvider: config.common.swapProvider,
        configurationManager: config.deployedContracts.core.configurationManager.address,
        weth: config.tokens.weth,
      },
    },
    deploymentId,
  })

  console.log(kleur.green().bold('AdmiralsQuarters Redeployed Successfully!'))

  // Update just the admiralsQuarters address in the core config
  const coreContracts = {
    ...config.deployedContracts.core,
    admiralsQuarters: result.admiralsQuarters,
  }
  updateIndexJson('core', network, coreContracts, useBummerConfig)

  // Set up governance roles for the new AdmiralsQuarters
  const updatedConfig = getConfigByNetwork(
    network,
    { common: true, gov: true, core: true },
    useBummerConfig,
  )
  await setupGovernanceRoles(updatedConfig)

  return result
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {string} network - The network being deployed to.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(network: string): Promise<boolean> {
  console.log(kleur.yellow(`AdmiralsQuarters will be redeployed on: ${network}`))
  return await continueDeploymentCheck()
}

async function setupGovernanceRoles(config: BaseConfig) {
  console.log(kleur.cyan().bold('Setting up governance roles for new AdmiralsQuarters...'))
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()
  console.log('Deployer: ', deployer.account.address)

  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )

  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])

  const hasAdmiralsQuartersRole = await protocolAccessManager.read.hasRole([
    ADMIRALS_QUARTERS_ROLE,
    config.deployedContracts.core.admiralsQuarters.address,
  ])

  if (hasGovernorRole) {
    // Deployer has governor role, can directly grant the admirals quarters role
    if (!hasAdmiralsQuartersRole) {
      console.log(
        '[PROTOCOL ACCESS MANAGER] - Granting admirals quarters role to new admirals quarters...',
      )
      const hash = await protocolAccessManager.write.grantAdmiralsQuartersRole([
        config.deployedContracts.core.admiralsQuarters.address,
      ])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green('AdmiralsQuarters role granted successfully!'))
    } else {
      console.log(kleur.yellow('AdmiralsQuarters already has the ADMIRALS_QUARTERS_ROLE'))
    }
  } else {
    console.log(kleur.yellow('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
    console.log(
      kleur.yellow(
        `ADMIRALS_QUARTERS_ROLE needs to be granted to ${config.deployedContracts.core.admiralsQuarters.address} via governance`,
      ),
    )
  }
}

redeployAdmiralsQuarters().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
