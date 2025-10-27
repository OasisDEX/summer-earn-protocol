import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, Hex, keccak256, toBytes } from 'viem'

interface ProposalAction {
  target: Address
  value: bigint
  calldata: Hex
}

export interface ProposalContent {
  title: string
  description: string
}

export interface ProposalDetails {
  title: string
  description: string
  governorId: string
  targets: Address[]
  values: string[]
  calldatas: Hex[]
  discourseURL?: string
  timestamp: number
  crossChainExecution?: {
    hubChain: {
      name: string
      governorAddress: string
      proposalId: string
    }
    targetChain: {
      name: string
      proposalId: string
      targets: string[]
      values: string[]
      datas: string[]
      predecessor: string
      delay: string
    }
  }
}

export interface ProposalData {
  targets: Address[]
  values: bigint[]
  calldatas: `0x${string}`[]
  description: string
  title: string
  crossChainExecution?: Array<{
    name: string
    chainId: number
    targets: string[]
    values: string[]
    datas: string[]
    predecessor: string
    delay: string
  }>
}

/**
 * Hashes a description string using keccak256
 * @param description The description to hash
 * @returns The hashed description as Hex
 */
export function hashDescription(description: string): Hex {
  return keccak256(toBytes(description))
}

/**
 * Helper function to prompt for SIP minor number
 */
export async function getSipMinorNumber(): Promise<number | undefined> {
  try {
    // Check if prompts package is available
    const prompts = require('prompts')

    const response = await prompts({
      type: 'number',
      name: 'value',
      message:
        'Enter the SIP minor number for this proposal (e.g., for SIP5.1 enter 1, leave empty for no minor number):',
      validate: (value) =>
        value === '' || (Number.isInteger(Number(value)) && Number(value) >= 0)
          ? true
          : 'Please enter a valid non-negative integer or leave empty',
    })

    return response.value === '' ? undefined : Number(response.value)
  } catch (error) {
    console.log(kleur.yellow('Could not prompt for SIP minor number, continuing without it.'))
    return undefined
  }
}

/**
 * Get the directory where proposal files are stored
 * @returns Path to the proposals directory
 */
export function getProposalsDirectory(): string {
  return path.join(process.cwd(), 'proposals')
}

/**
 * Get a list of all proposal JSON files in the proposals directory
 * @returns Array of filenames
 */
export function listProposalFiles(): string[] {
  const proposalsDir = getProposalsDirectory()

  // Create directory if it doesn't exist
  if (!fs.existsSync(proposalsDir)) {
    fs.mkdirSync(proposalsDir, { recursive: true })
    return []
  }

  return fs.readdirSync(proposalsDir).filter((file) => file.endsWith('.json'))
}

/**
 * Prompt the user to select a proposal file
 * @param message The prompt message to display
 * @returns The selected filename or undefined if canceled
 */
export async function promptForProposalFile(
  message = 'Select a proposal file:',
): Promise<string | undefined> {
  const files = listProposalFiles()

  if (files.length === 0) {
    console.log(kleur.red('No proposal files found in the proposals directory'))
    return undefined
  }

  const fileResponse = await prompts({
    type: 'select',
    name: 'filename',
    message,
    choices: files.map((file) => ({ title: file, value: file })),
  })

  if (!fileResponse.filename) {
    console.log(kleur.yellow('No file selected.'))
    return undefined
  }

  return fileResponse.filename
}

/**
 * Load a proposal from a JSON file
 * @param filename The filename to load
 * @returns The parsed proposal data
 */
export function loadProposalFile(filename: string): ProposalData {
  const proposalsDir = getProposalsDirectory()
  const filePath = path.join(proposalsDir, filename)

  console.log(kleur.yellow(`Loading proposal from: ${filePath}`))

  try {
    const fileContent = fs.readFileSync(filePath, 'utf8')
    const proposal = JSON.parse(fileContent)

    // Extract proposal data
    const { title, description, targets, values, calldatas, crossChainExecution } = proposal

    // Convert values from strings to BigInt
    const bigintValues = values.map((value: unknown) =>
      typeof value === 'string' ? BigInt(value) : BigInt(String(value)),
    )

    // Ensure calldatas are properly typed as 0x-prefixed strings
    const formattedCalldatas = calldatas.map((calldata: string) => calldata as `0x${string}`)

    // Handle legacy format (single target, value, data) for cross-chain execution
    let formattedCrossChainExecution = crossChainExecution
    if (
      crossChainExecution &&
      crossChainExecution.targetChain &&
      (('target' in crossChainExecution.targetChain &&
        !('targets' in crossChainExecution.targetChain)) ||
        ('value' in crossChainExecution.targetChain &&
          !('values' in crossChainExecution.targetChain)) ||
        ('data' in crossChainExecution.targetChain &&
          !('datas' in crossChainExecution.targetChain)))
    ) {
      // Convert legacy format to array format
      const { target, value, data, ...rest } = crossChainExecution.targetChain as any
      formattedCrossChainExecution = {
        ...crossChainExecution,
        targetChain: {
          ...rest,
          targets: [target],
          values: [value],
          datas: [data],
        },
      }
      console.log(kleur.yellow('Converted legacy cross-chain format to array format'))
    }

    return {
      title,
      description,
      targets: targets as Address[],
      values: bigintValues,
      calldatas: formattedCalldatas,
      crossChainExecution: formattedCrossChainExecution,
    }
  } catch (error) {
    console.error(kleur.red('Error processing proposal file:'), error)
    throw error
  }
}

/**
 * Display a summary of the proposal data
 * @param proposal The proposal data to display
 */
export function displayProposalSummary(proposal: ProposalData): void {
  console.log(kleur.cyan('Proposal Summary:'))
  console.log(kleur.blue('Title:'), proposal.title)
  console.log(
    kleur.blue('Description:'),
    proposal.description.substring(0, 200) + (proposal.description.length > 200 ? '...' : ''),
  )
  console.log(kleur.blue('Number of actions:'), proposal.targets.length)

  // Display cross-chain information if available
  if (proposal.crossChainExecution && Array.isArray(proposal.crossChainExecution)) {
    console.log(kleur.blue('Cross-Chain Proposal:'))
    console.log(kleur.blue('  Target Chains:'), proposal.crossChainExecution.length)

    proposal.crossChainExecution.forEach((chain, index) => {
      console.log(kleur.blue(`  Chain ${index + 1}:`), chain.name)
      console.log(kleur.blue('    Chain ID:'), chain.chainId)
      console.log(kleur.blue('    Actions:'), chain.targets.length)
    })
  } else if (proposal.crossChainExecution && proposal.crossChainExecution.targetChain) {
    console.log(kleur.blue('Cross-Chain Proposal:'))
    console.log(kleur.blue('  Target Chain:'), proposal.crossChainExecution.targetChain.name)
    console.log(kleur.blue('  Actions:'), proposal.crossChainExecution.targetChain.targets.length)
  }

  // Display each action
  console.log(kleur.blue('\nActions:'))
  proposal.targets.forEach((target, index) => {
    console.log(kleur.blue(`  ${index + 1}. Target:`), target)
    console.log(kleur.blue('     Value:'), proposal.values[index].toString())
    console.log(kleur.blue('     Calldata:'), proposal.calldatas[index].substring(0, 20) + '...')
  })
}

/**
 * Creates a governance proposal and saves it to a JSON file
 * @param title The proposal title
 * @param description The proposal description
 * @param actions Array of proposal actions
 * @param governorAddress The governor contract address
 * @param chainId The chain ID
 * @param discourseURL Optional Discourse URL
 * @param actionSummary Optional action summary
 * @param savePath Optional custom save path
 * @param crossChainExecution Optional cross-chain execution details
 */
export async function createGovernanceProposal(
  title: string,
  description: string,
  actions: ProposalAction[],
  governorAddress: Address,
  chainId: number,
  discourseURL: string = '',
  actionSummary: string[] = [],
  savePath?: string,
  crossChainExecution?: any,
): Promise<void> {
  const governorId = `eip155:${chainId}:${governorAddress}`

  // Convert actions to the format expected by Tally
  const executableCalls = actions.map((action) => ({
    target: action.target,
    calldata: action.calldata,
    signature: '', // Will be filled by Tally
    value: action.value.toString(),
    type: 'CALL',
  }))

  // Create proposal data
  const proposalData: ProposalDetails = {
    title,
    description,
    governorId,
    targets: actions.map((action) => action.target),
    values: actions.map((action) => action.value.toString()),
    calldatas: actions.map((action) => action.calldata),
    discourseURL,
    timestamp: Date.now(),
    crossChainExecution,
  }

  // Generate save path if not provided
  if (!savePath) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const proposalsDir = getProposalsDirectory()
    savePath = path.join(proposalsDir, `proposal_${timestamp}.json`)
  }

  // Ensure proposals directory exists
  const proposalsDir = path.dirname(savePath)
  if (!fs.existsSync(proposalsDir)) {
    fs.mkdirSync(proposalsDir, { recursive: true })
  }

  // Save proposal to file
  fs.writeFileSync(savePath, JSON.stringify(proposalData, null, 2))

  console.log(kleur.green(`Proposal saved to: ${savePath}`))
  console.log(kleur.cyan('Proposal Summary:'))
  console.log(`Title: ${title}`)
  console.log(`Governor: ${governorAddress}`)
  console.log(`Chain ID: ${chainId}`)
  console.log(`Actions: ${actions.length}`)
  if (discourseURL) {
    console.log(`Discourse: ${discourseURL}`)
  }
  if (actionSummary.length > 0) {
    console.log('Action Summary:')
    actionSummary.forEach((action, index) => {
      console.log(`  ${index + 1}. ${action}`)
    })
  }
}
