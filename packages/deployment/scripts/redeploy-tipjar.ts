import hre from 'hardhat'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import { Address } from 'viem'
import { TipJarContracts, createTipJarModule } from '../ignition/modules/tipjar'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'

interface TipStream {
  recipient: Address
  allocation: string
  minTerm: string
}

interface TipStreamsConfig {
  tipStreams: TipStream[]
}

/**
 * Deploys the TipJar contract and sets up tip streams.
 */
async function redeployTipJar() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Load the configuration for the current network
  const config = getConfigByNetwork(network, { common: true })

  // Deploy the TipJar contract
  const deployedTipJar = await deployTipJarContract(config)

  // Set up tip streams from the configuration
  await setupTipStreams(deployedTipJar.tipJar.address)

  console.log(kleur.green().bold('\nTipJar deployment and setup completed successfully!'))
  console.log(kleur.yellow('TipJar Address:'), kleur.cyan(deployedTipJar.tipJar.address))

  return deployedTipJar
}

/**
 * Deploys the TipJar contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<TipJarContracts>} The deployed TipJar contract.
 */
async function deployTipJarContract(config: BaseConfig): Promise<TipJarContracts> {
  console.log(kleur.cyan().bold('Deploying TipJar Contract...'))

  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  // Get token from configuration (assuming SUMMER token for TipJar)
  const tokenAddress = config.deployedContracts.gov.summerToken.address
  if (!tokenAddress) {
    throw new Error('SUMMER token address not found in configuration')
  }

  console.log(kleur.yellow('SUMMER Token Address:'), kleur.cyan(tokenAddress))

  // Deploy TipJar module
  return (await hre.ignition.deploy(
    createTipJarModule({
      token: tokenAddress as Address,
    }),
    {
      deploymentId,
    },
  )) as TipJarContracts
}

/**
 * Sets up tip streams according to the configuration.
 * @param {Address} tipJarAddress - The address of the deployed TipJar contract.
 */
async function setupTipStreams(tipJarAddress: Address): Promise<void> {
  console.log(kleur.cyan().bold('\nSetting up tip streams...'))

  try {
    // Load tip streams configuration
    const configPath = path.resolve(__dirname, '../launch-config/tip-streams.json')
    const tipStreamsConfig: TipStreamsConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'))

    if (!tipStreamsConfig.tipStreams || tipStreamsConfig.tipStreams.length === 0) {
      console.log(kleur.yellow('No tip streams configured. Skipping setup.'))
      return
    }

    // Get the TipJar contract instance
    const tipJar = await hre.viem.getContractAt('TipJar' as string, tipJarAddress)
    const [deployer] = await hre.viem.getWalletClients()
    const publicClient = await hre.viem.getPublicClient()

    console.log(kleur.yellow(`Setting up ${tipStreamsConfig.tipStreams.length} tip streams...`))

    // Add each tip stream
    for (const stream of tipStreamsConfig.tipStreams) {
      console.log(
        kleur.yellow(
          `Adding stream: ${stream.recipient} - ${stream.allocation} - Min Term: ${stream.minTerm} seconds`,
        ),
      )

      try {
        const hash = await tipJar.write.addTipStream(
          [stream.recipient, stream.allocation, stream.minTerm],
          { account: deployer.account },
        )

        await publicClient.waitForTransactionReceipt({ hash })
        console.log(kleur.green(`✅ Successfully added tip stream for ${stream.recipient}`))
      } catch (error) {
        console.error(kleur.red(`Failed to add tip stream for ${stream.recipient}:`), error)
      }
    }

    console.log(kleur.green().bold('All tip streams set up successfully!'))
  } catch (error) {
    console.error(kleur.red('Error setting up tip streams:'), error)
    throw error
  }
}

// Execute the script
redeployTipJar().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { redeployTipJar }
