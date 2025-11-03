import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'

import { GovContractsV2, GovModuleV2 } from '../../ignition/modules/gov-v2'
import { BaseConfig } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { ModuleLogger } from '../helpers/module-logger'
import { updateIndexJson } from '../helpers/update-json'
import { validateAddress } from '../helpers/validation'

export async function deployGov(config: BaseConfig, useBummerConfig?: boolean) {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const deployedGov = await deployGovContracts(config, useBummerConfig)
  ModuleLogger.logGovV2(deployedGov)

  console.log('Updating index.json...')
  updateIndexJson('gov', hre.network.name, deployedGov, useBummerConfig)

  return deployedGov
}

/**
 * Deploys the gov contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {boolean} [useBummerConfig] - Whether to use the bummer (test) configuration.
 * @returns {Promise<GovContractsV2>} The deployed gov contracts.
 */
async function deployGovContracts(
  config: BaseConfig,
  useBummerConfig?: boolean,
): Promise<GovContractsV2> {
  console.log(kleur.cyan().bold('Deploying Gov Contracts...'))

  const deployConfig = await getDeploymentConfig(useBummerConfig)
  const stakedSummerToken = validateAddress(
    config.deployedContracts.govV2.summerGovernanceToken.address,
    'govV2.summerGovernanceToken',
  )
  const timelock = validateAddress(config.deployedContracts.gov.timelock.address, 'gov.timelock')
  const accessManager = validateAddress(
    config.deployedContracts.gov.protocolAccessManager.address,
    'gov.protocolAccessManager',
  )
  const proposalThreshold = 10000n * 10n ** 18n
  const quorumFraction = 15n

  console.log('\n', kleur.yellow().bold('Please confirm governance configuration:'), '\n')
  console.log('\n', kleur.blue('Governance Configuration:'))
  console.log(
    '- Voting Delay:',
    kleur.cyan(`${deployConfig.votingDelay} seconds (${deployConfig.votingDelay / 86400n} days)`),
  )
  console.log(
    '- Voting Period:',
    kleur.cyan(`${deployConfig.votingPeriod} seconds (${deployConfig.votingPeriod / 86400n} days)`),
  )
  console.log('- Proposal Threshold:', kleur.cyan(`${proposalThreshold / 10n ** 18n} tokens`))
  console.log('- Quorum Fraction:', kleur.cyan(`${quorumFraction}% of total supply`))
  console.log('- LayerZero Endpoint:', kleur.cyan(config.common.layerZero.lzEndpoint))

  const confirmation = await prompts({
    type: 'confirm',
    name: 'value',
    message: 'Do you want to proceed with this configuration?',
    initial: true,
  })

  if (!confirmation.value) {
    throw new Error('Deployment cancelled by user')
  }

  if (config.common.layerZero.lzEndpoint === ADDRESS_ZERO) {
    throw new Error('LayerZero is not set up correctly')
  }

  console.log('Deploying Gov Module...')
  const gov = await hre.ignition.deploy(GovModuleV2, {
    parameters: {
      GovModuleV2: {
        lzEndpoint: config.common.layerZero.lzEndpoint,
        hubChainId: config.common.chainId,
        votingDelay: deployConfig.votingDelay,
        votingPeriod: deployConfig.votingPeriod,
        proposalThreshold: proposalThreshold,
        quorumFraction: quorumFraction,
        stakedSummerToken: stakedSummerToken,
        timelock: timelock,
        accessManager: accessManager,
      },
    },
  })

  console.log(kleur.green().bold('All Gov Contracts Deployed Successfully!'))

  return gov
}

/**
 * Gets the deployment configuration for governance contracts.
 * @param useBummerConfig - Whether to use the bummer (test) configuration.
 * @returns The deployment configuration.
 */
async function getDeploymentConfig(useBummerConfig?: boolean) {
  // Use the passed useBummerConfig instead of asking again
  const isTest = useBummerConfig === true

  const defaultVotingDelay = isTest ? 60n : 86400n // 1 min or 1 day
  const defaultVotingPeriod = isTest ? 600n : 259200n // 10 mins or 3 days

  const responses = await prompts([
    {
      type: 'number',
      name: 'votingDelay',
      message: 'Enter voting delay (in seconds):',
      initial: Number(defaultVotingDelay),
    },
    {
      type: 'number',
      name: 'votingPeriod',
      message: 'Enter voting period (in seconds):',
      initial: Number(defaultVotingPeriod),
    },
  ])

  return {
    votingDelay: BigInt(responses.votingDelay),
    votingPeriod: BigInt(responses.votingPeriod),
  }
}

if (require.main === module) {
  // If run directly, prompt for bummer config
  const promptForConfigType = async () => {
    const response = await prompts({
      type: 'confirm',
      name: 'value',
      message: 'Do you want to use the bummer configuration? (test environment)',
      initial: true,
    })
    return response.value
  }

  const getConfig = async () => {
    const useBummerConfig = await promptForConfigType()
    const config = getConfigByNetwork(
      hre.network.name,
      { common: true, gov: false, core: false },
      useBummerConfig,
    ) as BaseConfig
    return { config, useBummerConfig }
  }

  getConfig()
    .then(({ config, useBummerConfig }) => {
      return deployGov(config, useBummerConfig)
    })
    .catch((error) => {
      console.error(kleur.red().bold('An error occurred:'), error)
      process.exit(1)
    })
}
