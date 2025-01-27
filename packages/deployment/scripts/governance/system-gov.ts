import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'

import { GovContracts, GovModule } from '../../ignition/modules/gov'
import { BaseConfig } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { ModuleLogger } from '../helpers/module-logger'
import { updateIndexJson } from '../helpers/update-json'

export async function deployGov() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: false, core: false })
  const deployedGov = await deployGovContracts(config)
  ModuleLogger.logGov(deployedGov)
  return deployedGov
}

/**
 * Deploys the gov contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<GovContracts>} The deployed gov contracts.
 */
async function deployGovContracts(config: BaseConfig): Promise<GovContracts> {
  console.log(kleur.cyan().bold('Deploying Gov Contracts...'))

  const deployConfig = await getDeploymentConfig()
  const initialSupply = getInitialSupply(config)
  const proposalThreshold = 10000n * 10n ** 18n
  const quorumFraction = 4n

  // Format initial supply for display with underscores for readability
  const formattedInitialSupply = `${(initialSupply / 10n ** 18n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '_')} tokens (${18} decimal precision)`

  console.log('\n', kleur.yellow().bold('Please confirm governance configuration:'), '\n')
  console.log(kleur.blue('Token Configuration:'))
  console.log('- Name:', kleur.cyan(deployConfig.tokenName))
  console.log('- Symbol:', kleur.cyan(deployConfig.tokenSymbol))
  console.log('- Initial Supply:', kleur.cyan(formattedInitialSupply))
  console.log(
    '- Transfer Enable Date:',
    kleur.cyan(new Date(Number(deployConfig.transferEnableDate) * 1000).toLocaleString()),
  )

  console.log('\n', kleur.blue('Governance Configuration:'))
  console.log(
    '- Timelock Delay:',
    kleur.cyan(`${deployConfig.minDelay} seconds (${deployConfig.minDelay / 86400n} days)`),
  )
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
  const gov = await hre.ignition.deploy(GovModule, {
    parameters: {
      GovModule: {
        lzEndpoint: config.common.layerZero.lzEndpoint,
        initialSupply,
        tokenName: deployConfig.tokenName,
        tokenSymbol: deployConfig.tokenSymbol,
        transferEnableDate: deployConfig.transferEnableDate,
        minDelay: deployConfig.minDelay,
        votingDelay: deployConfig.votingDelay,
        votingPeriod: deployConfig.votingPeriod,
        proposalThreshold,
        quorumFraction,
      },
    },
  })

  console.log('Updating index.json...')
  updateIndexJson('gov', hre.network.name, gov)

  console.log(kleur.green().bold('All Gov Contracts Deployed Successfully!'))

  return gov
}

/**
 * Retrieves the initial supply of tokens from the configuration.
 *
 * @param config - The configuration object for the current network.
 * @returns The initial supply of tokens as a bigint, scaled to 18 decimal places.
 */
function getInitialSupply(config: BaseConfig): bigint {
  return BigInt(config.common.initialSupply) * 10n ** 18n
}

async function getDeploymentConfig() {
  const isTest = (
    await prompts({
      type: 'confirm',
      name: 'value',
      message: 'Is this a test deployment?',
      initial: true,
    })
  ).value

  const defaultName = isTest ? 'BummerToken' : 'SummerToken'
  const defaultSymbol = isTest ? 'BUMMER' : 'SUMR'
  const defaultMinDelay = isTest ? 300n : 172800n // 5 mins or 2 day
  const defaultVotingDelay = isTest ? 60n : 86400n // 1 min or 1 day
  const defaultVotingPeriod = isTest ? 600n : 345600n // 10 mins or 4 days

  // Calculate default transfer enable date
  const now = Math.floor(Date.now() / 1000)
  const july1st2025UTC = 1751328000 // July 1st, 2025 00:00 UTC
  const defaultTransferEnableDate = isTest
    ? now + 5 * 60 // 5 minutes from now
    : july1st2025UTC

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
      name: 'minDelay',
      message: 'Enter minimum delay for timelock (in seconds):',
      initial: Number(defaultMinDelay),
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
  ])

  return {
    tokenName: responses.tokenName as string,
    tokenSymbol: responses.tokenSymbol as string,
    transferEnableDate: BigInt(responses.transferEnableDate),
    minDelay: BigInt(responses.minDelay),
    votingDelay: BigInt(responses.votingDelay),
    votingPeriod: BigInt(responses.votingPeriod),
  }
}

if (require.main === module) {
  deployGov().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
