import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { createSummerVestingFactoryV2Module } from '../ignition/modules/summerVestingFactoryV2ModuleFactory'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'
import { updateIndexJson } from './helpers/update-json'

export async function deploySummerVestingFactoryV2() {
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
  const config = getConfigByNetwork(network, { common: true, gov: true }, useBummerConfig)

  // Check for FOUNDATION_ADDRESS environment variable
  const foundationAddress = process.env.FOUNDATION_ADDRESS
  if (!foundationAddress) {
    console.log(
      kleur.red().bold('FOUNDATION_ADDRESS environment variable is required but not set.'),
    )
    console.log(kleur.yellow('Please set FOUNDATION_ADDRESS in your .env file.'))
    return null
  }

  // Display summary and get confirmation
  if (!(await confirmDeployment(network, foundationAddress))) {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }

  console.log(kleur.cyan().bold('Deploying SummerVestingFactoryV2...'))

  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const timestampString = new Date().toISOString().replace(/[-:Z.]/g, '')
  const moduleName = `SummerVestingFactoryV2Module_${timestampString}`
  const SummerVestingFactoryV2Module = createSummerVestingFactoryV2Module(moduleName)

  const result = await hre.ignition.deploy(SummerVestingFactoryV2Module, {
    parameters: {
      [moduleName]: {
        token: config.deployedContracts.gov.summerToken.address,
        owner: foundationAddress,
      },
    },
    deploymentId,
  })

  console.log(kleur.green().bold('SummerVestingFactoryV2 Deployed Successfully!'))
  console.log(kleur.cyan('Contract Address:'), kleur.white(result.summerVestingFactoryV2.address))
  console.log(kleur.cyan('Owner:'), kleur.white(foundationAddress))
  console.log(kleur.cyan('Token:'), kleur.white(config.deployedContracts.gov.summerToken.address))

  // Update the index.json with the new contract
  const govContracts = {
    ...config.deployedContracts.gov,
    summerVestingFactoryV2: result.summerVestingFactoryV2,
  }
  updateIndexJson('gov', network, govContracts, useBummerConfig)

  console.log(kleur.green('✅ Index.json updated successfully!'))
  console.log(kleur.green('✅ SummerVestingFactoryV2 added to gov contracts'))

  return result
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {string} network - The network being deployed to.
 * @param {string} foundationAddress - The foundation address that will own the factory.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(network: string, foundationAddress: string): Promise<boolean> {
  console.log(kleur.yellow(`SummerVestingFactoryV2 will be deployed on: ${network}`))
  console.log(kleur.cyan('Foundation Address:'), kleur.white(foundationAddress))
  console.log(kleur.cyan('Token:'), kleur.white('Summer Token (from config)'))
  return await continueDeploymentCheck()
}

deploySummerVestingFactoryV2().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
