import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'

import { GovContractsV2, createGovV2Module } from '../../ignition/modules/gov-v2'
import { BaseConfig } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { ModuleLogger } from '../helpers/module-logger'
import { updateIndexJson } from '../helpers/update-json'
import { validateAddress } from '../helpers/validation'
import { isHubChain } from '../helpers/get-hub-chain'
import { createGovV1CoreModule } from '../../ignition/modules/gov-v1-core'

type DeployConfig = {
  tokenName: string
  tokenSymbol: string
  transferEnableDate: bigint
  votingDelay: bigint
  votingPeriod: bigint
  minDelay: bigint
}

export async function deployGovV2(config: BaseConfig, useBummerConfig?: boolean) {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const deployConfig = await getDeploymentConfig(useBummerConfig)
  if (
    config.deployedContracts.gov.timelock.address === ADDRESS_ZERO ||
    config.deployedContracts.gov.protocolAccessManager.address === ADDRESS_ZERO ||
    config.deployedContracts.gov.summerToken.address === ADDRESS_ZERO
  ) {
    console.log(
      'Timelock, access manager or summer token is not deployed, deploying GovV1CoreModule...',
    )
    const govV1Core = await deployGovV1Core(deployConfig, useBummerConfig)
    ModuleLogger.logGovV1Core(govV1Core)
  }

  const deployedGov = await deployGovV2Contracts(deployConfig, useBummerConfig)
  ModuleLogger.logGovV2(deployedGov)

  return deployedGov
}

/**
 * Deploys the timelock and protocol access manager contracts using Hardhat Ignition.
 * @param {Object} deployConfig - The deployment configuration object.
 * @param {boolean} useBummerConfig - Whether to use the bummer configuration.
 * @returns {Promise<GovV1CoreContracts>} The deployed timelock and protocol access manager contracts.
 */
async function deployGovV1Core(deployConfig: DeployConfig, useBummerConfig?: boolean) {
  console.log(kleur.cyan().bold('Deploying GovV1Core...'))
  const config = getConfigByNetwork(hre.network.name, { gov: false }, useBummerConfig) as BaseConfig
  if (config.common.layerZero.lzEndpoint === ADDRESS_ZERO) {
    throw new Error('LayerZero is not set up correctly')
  }
  // Only add 'staging' prefix if bummer, no prefix for prod (for compatibility)
  const moduleName = useBummerConfig ? 'staging_GovV1CoreModule' : 'GovV1CoreModule'
  const govV1CoreModule = createGovV1CoreModule(moduleName)
  const govV1Core = await hre.ignition.deploy(govV1CoreModule, {
    parameters: {
      [moduleName]: {
        minDelay: deployConfig.minDelay,
        tokenName: deployConfig.tokenName,
        tokenSymbol: deployConfig.tokenSymbol,
        transferEnableDate: deployConfig.transferEnableDate,
        lzEndpoint: config.common.layerZero.lzEndpoint,
      },
    },
  })
  updateIndexJson('gov', hre.network.name, govV1Core, useBummerConfig)
  return govV1Core
}
/**
 * Deploys the gov contracts using Hardhat Ignition.
 * @param {Object} deployConfig - The deployment configuration object.
 * @param {boolean} useBummerConfig - Whether to use the bummer configuration.
 * @returns {Promise<GovContractsV2>} The deployed gov contracts.
 */
async function deployGovV2Contracts(
  deployConfig: DeployConfig,
  useBummerConfig?: boolean,
): Promise<GovContractsV2> {
  const config = getConfigByNetwork(hre.network.name, { gov: false }, useBummerConfig) as BaseConfig
  console.log(kleur.cyan().bold('Deploying Gov Contracts...'))
  const summerGovernanceToken = isHubChain(hre.network.name)
    ? validateAddress(
        config.deployedContracts.govV2.summerGovernanceToken.address,
        'govV2.summerGovernanceToken',
      )
    : validateAddress(config.deployedContracts.gov.summerToken.address, 'gov.summerToken')
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
  // Only add 'staging' prefix if bummer, no prefix for prod (for compatibility)
  const moduleName = useBummerConfig ? 'staging_GovModuleV2' : 'GovModuleV2'
  const govModule = createGovV2Module(moduleName)
  const gov = await hre.ignition.deploy(govModule, {
    parameters: {
      [moduleName]: {
        lzEndpoint: config.common.layerZero.lzEndpoint,
        hubChainId: config.common.chainId,
        votingDelay: deployConfig.votingDelay,
        votingPeriod: deployConfig.votingPeriod,
        proposalThreshold: proposalThreshold,
        quorumFraction: quorumFraction,
        summerGovernanceToken: summerGovernanceToken,
        timelock: timelock,
        accessManager: accessManager,
      },
    },
  })

  console.log(kleur.green().bold('All Gov Contracts Deployed Successfully!'))

  console.log('Updating index.json...')
  const contracts = {
    ...gov,
    timelock: JSON.parse(JSON.stringify(config.deployedContracts.gov.timelock)),
    protocolAccessManager: JSON.parse(
      JSON.stringify(config.deployedContracts.gov.protocolAccessManager),
    ),
  }
  updateIndexJson('govV2', hre.network.name, contracts, useBummerConfig)

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

  const defaultName = isTest ? 'BummerToken' : 'SummerToken'
  const defaultSymbol = isTest ? 'BUMMER' : 'SUMR'
  const defaultVotingDelay = isTest ? 60n : 86400n // 1 min or 1 day
  const defaultVotingPeriod = isTest ? 600n : 259200n // 10 mins or 3 days
  const defaultMinDelay = isTest ? 60n : 86400n // 1 min or 1 day

  const july1st2025UTC = 1751328000 // July 1st, 2025 00:00 UTC
  const defaultTransferEnableDate = isTest ? 0 : july1st2025UTC

  const responses = await prompts([
    {
      type: 'text',
      name: 'tokenName',
      message: 'Enter token name:',
      initial: defaultName,
    },
    {
      type: 'text',
      name: 'tokenSymbol',
      message: 'Enter token symbol:',
      initial: defaultSymbol,
    },
    {
      type: 'number',
      name: 'transferEnableDate',
      message: 'Enter transfer enable date (unix timestamp):',
      initial: defaultTransferEnableDate,
    },
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
    {
      type: 'number',
      name: 'minDelay',
      message: 'Enter min delay for timelock (in seconds):',
      initial: Number(defaultMinDelay),
    },
  ])

  return {
    tokenName: responses.tokenName as string,
    tokenSymbol: responses.tokenSymbol as string,
    transferEnableDate: BigInt(responses.transferEnableDate),
    votingDelay: BigInt(responses.votingDelay),
    votingPeriod: BigInt(responses.votingPeriod),
    minDelay: BigInt(responses.minDelay),
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
      return deployGovV2(config, useBummerConfig)
    })
    .catch((error) => {
      console.error(kleur.red().bold('An error occurred:'), error)
      process.exit(1)
    })
}
