import kleur from 'kleur'
import prompts from 'prompts'
import { Address, Hex, encodeFunctionData, parseAbi } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { submitProposal } from '../helpers/governance-helpers'

const hre = require('hardhat')

async function setupGovernanceRewards() {
  const network = hre.network.name
  const isHubChain = network === 'base' // Using 'base' as the hub chain name

  // Prompt for bummer config
  const { useBummerConfig } = await prompts({
    type: 'confirm',
    name: 'useBummerConfig',
    message: 'Use bummer config?',
    initial: false,
  })

  // Get configuration
  const config = getConfigByNetwork(network, { gov: true }, useBummerConfig)
  if (!config) {
    throw new Error(`No configuration found for network ${network}`)
  }

  // Get required addresses from config
  const timelockAddress = config.deployedContracts.gov.timelock.address as Address
  const summerTokenAddress = config.deployedContracts.gov.summerToken.address as Address
  const governorAddress = config.deployedContracts.govV2.summerGovernor.address as Address

  if (!timelockAddress || !summerTokenAddress || !governorAddress) {
    throw new Error('Required contract addresses not found in config')
  }

  // Get rewards manager address from SummerToken
  const summerToken = await hre.viem.getContractAt('SummerToken' as string, summerTokenAddress)
  const rewardsManagerAddress = await summerToken.read.rewardsManager()

  // Get the minor number for this proposal
  const minorNumber = await getSipMinorNumber()
  const minorNumberStr = minorNumber ? `.${minorNumber}` : ''

  // Prompt for reward parameters
  const { rewardAmount, rewardDuration } = await prompts([
    {
      type: 'number',
      name: 'rewardAmount',
      message: 'Enter the reward amount (in whole SUMR tokens):',
      validate: (value) => (value > 0 ? true : 'Amount must be greater than 0'),
    },
    {
      type: 'number',
      name: 'rewardDuration',
      message: 'Enter the reward duration (in seconds):',
      initial: 604800, // 1 week in seconds
      validate: (value) => (value > 0 ? true : 'Duration must be greater than 0'),
    },
  ])

  // Convert reward amount to wei (assuming 18 decimals)
  // fetch the token’s actual decimals instead of assuming 18
  const decimals = await summerToken.read.decimals()
  const rewardAmountInWei = BigInt(rewardAmount) * BigInt(10 ** decimals)

  // Prepare proposal actions
  const targets: Address[] = []
  const values: bigint[] = []
  const calldatas: Hex[] = []

  // 1. Approve rewards manager to spend tokens
  targets.push(summerTokenAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function approve(address spender, uint256 amount)']),
      args: [rewardsManagerAddress, rewardAmountInWei],
    }) as Hex,
  )

  // 2. Notify reward amount
  targets.push(rewardsManagerAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: parseAbi([
        'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration)',
      ]),
      args: [summerTokenAddress, rewardAmountInWei, BigInt(rewardDuration)],
    }) as Hex,
  )

  // Create proposal title
  const title = `SIP3${minorNumberStr}: Set Up Governance Staking Rewards`

  // Create proposal description body
  const descriptionBody = `## Summary
This proposal sets up rewards for governance staking.

## Motivation
Setting up rewards incentivizes governance participation and staking in the protocol.

## Technical Details
- Reward Token: SUMR (${summerTokenAddress})
- Reward Amount: ${rewardAmount} SUMR (${rewardAmountInWei})
- Reward Duration: ${Math.round(rewardDuration / 86400)} days (${rewardDuration} seconds)
- Rewards Manager: ${rewardsManagerAddress}

## Specifications
### Actions
This proposal will execute the following actions:
1. Approve the rewards manager to spend ${rewardAmount} SUMR tokens
2. Notify reward amount of ${rewardAmount} SUMR tokens with a duration of ${Math.round(rewardDuration / 86400)} days`

  // Prepend title to description body
  const description = `# ${title}\n\n${descriptionBody}`

  // Show summary and confirm
  console.log(kleur.cyan('\nGovernance Rewards Summary:'))
  console.log(kleur.yellow(`Reward Amount: ${rewardAmount} SUMR`))
  console.log(
    kleur.yellow(
      `Reward Duration: ${Math.round(rewardDuration / 86400)} days (${rewardDuration} seconds)`,
    ),
  )
  console.log(kleur.yellow(`Rewards Manager: ${rewardsManagerAddress}`))

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: 'Proceed with creating governance proposal?',
    initial: true,
  })

  if (confirmed) {
    try {
      // Submit proposal
      await submitProposal({
        title,
        description,
        targets,
        values,
        calldatas,
        governorAddress,
        useBummerConfig,
      })

      console.log(kleur.green().bold(`\nProposal creation process completed successfully!`))
    } catch (error: any) {
      console.error(kleur.red('Error creating proposal:'), error)
      if (error.cause?.data) {
        console.error(kleur.red('Error data:'), error.cause.data)
      }
    }
  } else {
    console.log(kleur.red().bold('Operation cancelled by user.'))
  }
}

setupGovernanceRewards().catch(console.error)
