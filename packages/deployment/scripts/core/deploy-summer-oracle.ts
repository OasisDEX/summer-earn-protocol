import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { getConfigByNetwork } from '../helpers/config-handler'
import { continueDeploymentCheck, promptForConfigType } from '../helpers/prompt-helpers'

import { parseAbi } from 'viem'

const summerOracleFactoryAbi = parseAbi([
  'function deploySummerOracle(address fleet) external returns (address)',
])

const harborCommandAbi = parseAbi([
  'function activeFleetCommanders(address) external view returns (bool)',
])

export async function deploySummerOracleForFleet() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(network, { common: true, core: true }, useBummerConfig)

  if (!(await confirmDeployment(network, config))) {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }

  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()

  const factoryAddress = (config.deployedContracts.core as any).summerOracleFactory?.address as
    | Address
    | undefined
  if (!factoryAddress) {
    throw new Error(
      'Missing summerOracleFactory address in core config. Run deploy-summer-oracle-factory first.',
    )
  }

  const harborCommand = config.deployedContracts.core.harborCommand.address as Address

  // Prompt for target FleetCommander address
  const response = await prompts({
    type: 'text',
    name: 'fleet',
    message: 'FleetCommander address to deploy oracle for:',
    validate: (value) => /^0x[a-fA-F0-9]{40}$/.test(value) || 'Invalid address',
  })
  const fleet = response.fleet as Address

  // Validate fleet is enlisted
  const enlisted = (await publicClient.readContract({
    address: harborCommand,
    abi: harborCommandAbi,
    functionName: 'activeFleetCommanders',
    args: [fleet],
  })) as boolean

  if (!enlisted) {
    throw new Error(
      'FleetCommander is not enlisted in HarborCommand; enlist before deploying oracle.',
    )
  }

  console.log(kleur.cyan('Deploying SummerOracle via factory...'))

  const hash = await publicClient.writeContract({
    address: factoryAddress,
    abi: summerOracleFactoryAbi,
    functionName: 'deploySummerOracle',
    account: deployer.account,
    args: [fleet],
  })

  const receipt = await publicClient.waitForTransactionReceipt({ hash })
  const deployed = receipt.contractAddress
  console.log(kleur.green().bold('SummerOracle deployed via factory tx:'), hash)

  return { tx: hash, receipt }
}

async function confirmDeployment(network: string, config: BaseConfig): Promise<boolean> {
  console.log(kleur.yellow(`SummerOracle will be deployed via factory on: ${network}`))
  console.log(kleur.yellow(`HarborCommand: ${config.deployedContracts.core.harborCommand.address}`))
  return await continueDeploymentCheck()
}

deploySummerOracleForFleet().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
