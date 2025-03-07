import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, parseAbi } from 'viem'
import { getConfigByNetwork } from './config-handler'
import { hashDescription } from './hash-description'

/**
 * Checks if the user has enough SUMR tokens to create a governance proposal
 * @returns A status object with balance information and whether requirements are met
 */
export async function checkProposerTokenRequirements(useBummerConfig: boolean): Promise<{
  hasEnoughTokens: boolean
  votingPower?: string
  requiredTokens?: string
  error?: string
}> {
  try {
    const [deployer] = await hre.viem.getWalletClients()
    console.log(kleur.yellow(`Deployer: ${deployer.account.address}`))
    const sumrTokenAddress = await getSumrTokenAddress(useBummerConfig)
    console.log(kleur.yellow(`Sumr token address: ${sumrTokenAddress}`))
    const sumrToken = await hre.viem.getContractAt('SummerToken' as string, sumrTokenAddress)

    const balance = await sumrToken.read.balanceOf([deployer.account.address])
    const delegatedVotes = await sumrToken.read.getVotes([deployer.account.address])
    console.log(kleur.yellow(`Balance: ${balance}`))
    console.log(kleur.yellow(`Delegated votes: ${delegatedVotes}`))
    const totalVotingPower = BigInt(String(balance)) + BigInt(String(delegatedVotes))

    // Get the proposal threshold from the governor contract
    const network = hre.network.name
    const config = getConfigByNetwork(
      network,
      { common: true, gov: true, core: true },
      useBummerConfig,
    )
    const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
    const governor = await hre.viem.getContractAt('SummerGovernor' as string, governorAddress)
    const minRequiredTokens = await governor.read.proposalThreshold()

    return {
      hasEnoughTokens: totalVotingPower >= BigInt(String(minRequiredTokens)),
      votingPower: formatEther(totalVotingPower),
      requiredTokens: formatEther(BigInt(String(minRequiredTokens))),
    }
  } catch (error) {
    return {
      hasEnoughTokens: false,
      error: 'Could not verify token balance',
    }
  }
}

/**
 * Validates if the proposal follows governance process requirements
 * @returns A boolean indicating if all governance steps have been completed
 */
export async function validateGovernanceProcess(): Promise<boolean> {
  const governanceChecks = await prompts([
    {
      type: 'confirm',
      name: 'forumDiscussion',
      message: 'Have you posted this proposal idea in the Lazy Summer Protocol Forum?',
      initial: false,
    },
    {
      type: 'confirm',
      name: 'rfcCompleted',
      message: 'Has this proposal completed the minimum 3-day Request for Comments (RFC) period?',
      initial: false,
    },
    {
      type: 'confirm',
      name: 'detailsComplete',
      message:
        'Does this proposal include all necessary details (Summary, Motivation, Specifications)?',
      initial: false,
    },
  ])

  return (
    governanceChecks.forumDiscussion &&
    governanceChecks.rfcCompleted &&
    governanceChecks.detailsComplete
  )
}

/**
 * Checks and corrects SIP naming convention if needed
 * @param title The original proposal title
 * @returns The updated title with proper SIP naming (if changed)
 */
export async function validateSipNaming(title: string): Promise<string> {
  if (!title.match(/^SIP\d+\.\d+/)) {
    console.log(kleur.yellow('\nSuggested SIP Naming:'))
    console.log('This appears to be an ARK Management proposal (SIP2 category).')
    console.log(kleur.cyan('Suggested title format: "SIP2.X: ' + title + '"'))

    const renameResponse = await prompts({
      type: 'confirm',
      name: 'rename',
      message: 'Would you like to use the suggested SIP naming convention?',
      initial: true,
    })

    if (renameResponse.rename) {
      return `SIP2.X: ${title}`
    }
  }

  return title
}

/**
 * Displays the governance rules for SIPs
 */
export function displayGovernanceRules(): void {
  console.log('\n============= GOVERNANCE COMPLIANCE =============')
  console.log(kleur.cyan().bold('According to SIP0 Governance Rules:'))
  console.log(kleur.yellow('1. Proposal Stages:'))
  console.log('   - Idea Submission in the Lazy Summer Protocol Forum')
  console.log('   - Request for Comments (RFC) Phase (minimum 3-day period)')
  console.log('   - SIP Submission with all necessary details')
  console.log('   - On-Chain Voting (4-day period)')
  console.log('   - Execution (2-day TimeLock period)')

  console.log(kleur.yellow('\n2. Proposer Requirements:'))
  console.log('   - Must hold or be delegated at least 10,000 $SUMR tokens')

  console.log(kleur.yellow('\n3. Voting Requirements:'))
  console.log('   - Quorum: 35% of actively delegated token supply')
  console.log('   - Passing threshold: Over 50% of votes in favor')
}

/**
 * Displays a summary of the proposal details
 */
export function displayProposalSummary(
  title: string,
  description: string,
  targets: Address[],
  values: bigint[],
  governorAddress: Address,
): void {
  console.log('\n============= PROPOSAL SUMMARY =============')
  console.log(`Title: ${title}`)
  console.log('\nDescription:')
  console.log(description)

  console.log('\nTechnical Details:')
  console.log(`- Governor Address: ${governorAddress}`)
  console.log(`- Number of Actions: ${targets.length}`)

  // Display each action in the proposal
  for (let i = 0; i < targets.length; i++) {
    console.log(`\nAction ${i + 1}:`)
    console.log(`- Target Contract: ${targets[i]}`)
    console.log(`- Value: ${values[i]} ETH`)
  }
}

/**
 * Submits a governance proposal to the governor contract
 */
export async function submitProposal({
  title,
  description,
  targets,
  values,
  calldatas,
  governorAddress,
  useBummerConfig,
}: {
  title: string
  description: string
  targets: Address[]
  values: bigint[]
  calldatas: `0x${string}`[]
  governorAddress: Address
  useBummerConfig: boolean
}): Promise<boolean> {
  // Display proposal summary
  displayProposalSummary(title, description, targets, values, governorAddress)

  // Display governance rules
  displayGovernanceRules()

  // Check if user has enough tokens
  const tokenRequirements = await checkProposerTokenRequirements(useBummerConfig)
  if (!tokenRequirements.hasEnoughTokens) {
    console.log(kleur.red().bold('\n⚠️ WARNING: Proposer Token Requirements Not Met'))
    console.log(
      `You have ${tokenRequirements.votingPower || '0'} SUMR voting power, but ${
        tokenRequirements.requiredTokens
      } SUMR is required to create a proposal.`,
    )
    console.log('Consider delegating more tokens before proceeding.')
  }

  // Validate the governance process
  const processValid = await validateGovernanceProcess()
  if (!processValid) {
    console.log(kleur.red().bold('\n⚠️ WARNING: Governance Process Not Complete'))
    console.log('Please ensure you have completed all required governance steps before proceeding.')
  }

  // Validate SIP naming
  const updatedTitle = await validateSipNaming(title)
  if (updatedTitle !== title) {
    console.log(kleur.green().bold('\nUpdated title:'), updatedTitle)
    title = updatedTitle
  }

  // Check if user wants to proceed
  const response = await prompts({
    type: 'confirm',
    name: 'continue',
    message: 'Do you want to submit this proposal on-chain?',
    initial: false,
  })

  if (response.continue) {
    console.log('\nSubmitting proposal on-chain...')

    try {
      // Get the public client and wallet client
      const publicClient = await hre.viem.getPublicClient()
      const [walletClient] = await hre.viem.getWalletClients()

      // Create ABI for propose function
      const governorAbi = parseAbi([
        'function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public returns (uint256)',
      ])

      // Submit proposal on-chain
      const hash = await walletClient.writeContract({
        address: governorAddress,
        abi: governorAbi,
        functionName: 'propose',
        args: [targets, values, calldatas, description],
        gas: 500000n,
        maxFeePerGas: await publicClient.getGasPrice(),
      })

      console.log(`\nProposal submitted. Transaction hash: ${hash}`)

      // Wait for the transaction to be mined
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      console.log(`Proposal transaction mined. Block number: ${receipt.blockNumber}`)

      // Get the proposal ID if possible
      try {
        // Create contract instance to read the proposal ID
        const governorContract = await hre.viem.getContractAt(
          'SummerGovernor' as string,
          governorAddress,
        )
        const proposalId = await governorContract.read.hashProposal([
          targets,
          values,
          calldatas,
          hashDescription(description),
        ])
        console.log(`Proposal ID: ${proposalId}`)

        // Reminder about next steps in governance process
        console.log(kleur.cyan().bold('\nNext Steps in Governance Process:'))
        console.log('1. The proposal will undergo a 4-day on-chain voting period')
        console.log('2. If approved, it will enter a 2-day TimeLock before execution')
        console.log('3. Monitor the proposal status and engage the community for support')
      } catch (error) {
        console.log('Note: Could not extract proposal ID')
      }

      return true
    } catch (error: any) {
      console.error(`Error submitting proposal: ${error.message}`)
      if (error.cause) {
        console.error('Error cause:', error.cause)
      }
      return false
    }
  } else {
    console.log('\nProposal submission cancelled.')
    return false
  }
}

/**
 * Helper function to get the SUMR token address
 */
export async function getSumrTokenAddress(useBummerConfig: boolean): Promise<Address> {
  // Get from config
  const network = hre.network.name
  const config = getConfigByNetwork(
    network,
    { common: true, gov: true, core: true },
    useBummerConfig,
  )
  return config.deployedContracts.gov.summerToken.address as Address
}

/**
 * Helper to format ETH values
 */
export function formatEther(value: bigint): string {
  return (Number(value) / 1e18).toFixed(2)
}
