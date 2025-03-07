import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, Hex } from 'viem'
import { createTallyProposal, formatTallyProposalUrl } from './tally-helpers'

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
  crossChainExecution?: {
    hubChain: {
      name: string
      governorAddress: string
    }
    targetChain: {
      name: string
      targets: string[]
      values: string[]
      datas: string[]
      predecessor: string
      delay: string
    }
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
  if (proposal.crossChainExecution) {
    console.log(kleur.blue('Cross-Chain Proposal:'))
    console.log(kleur.blue('  Hub Chain:'), proposal.crossChainExecution.hubChain.name)
    console.log(kleur.blue('  Target Chain:'), proposal.crossChainExecution.targetChain.name)

    // Display number of target chain actions
    if (proposal.crossChainExecution.targetChain.targets) {
      console.log(
        kleur.blue('  Target Chain Actions:'),
        proposal.crossChainExecution.targetChain.targets.length,
      )
    }
  }
}

/**
 * Load a proposal by prompting the user to select a file
 * @param promptMessage Optional custom message for the prompt
 * @returns The loaded proposal data or undefined if canceled
 */
export async function loadProposal(
  promptMessage = 'Select a proposal file to execute:',
): Promise<ProposalData | undefined> {
  const filename = await promptForProposalFile(promptMessage)
  if (!filename) {
    return undefined
  }

  const proposal = loadProposalFile(filename)
  displayProposalSummary(proposal)

  return proposal
}

/**
 * Save proposal details to a JSON file
 * @param proposalDetails The proposal details to save
 * @param savePath The path to save the file to
 * @returns The path where the file was saved
 */
export function saveProposalToFile(proposalDetails: ProposalDetails, savePath: string): string {
  // Create directory if it doesn't exist
  fs.mkdirSync(path.dirname(savePath), { recursive: true })

  // Generate a unique filename if not provided
  const finalPath = savePath.endsWith('.json')
    ? savePath
    : path.join(savePath, `proposal-${Date.now()}.json`)

  // Save the file
  fs.writeFileSync(finalPath, JSON.stringify(proposalDetails, null, 2))
  console.log(kleur.green(`Proposal details saved to: ${finalPath}`))

  return finalPath
}

/**
 * Creates a governance proposal using Tally API and saves proposal details to a JSON file
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
): Promise<string | undefined> {
  try {
    // Log proposal actions
    console.log(kleur.cyan('Creating Tally draft proposal with the following actions:'))
    if (actionSummary.length > 0) {
      actionSummary.forEach((action) => console.log(kleur.yellow(action)))
    }

    // Log discourse URL if provided
    if (discourseURL) {
      console.log(kleur.blue('Using Discourse URL:'), kleur.cyan(discourseURL))
    }

    // Format governor ID for Tally
    const governorId = `eip155:${chainId}:${governorAddress}`

    // Create executable calls array for Tally
    const executableCalls = actions.map((action) => ({
      target: action.target,
      calldata: action.calldata,
      signature: '',
      value: action.value.toString(),
      type: 'custom',
    }))

    // Save proposal details to JSON file if a path is provided
    if (savePath) {
      const proposalDetails: ProposalDetails = {
        title,
        description,
        governorId,
        targets: actions.map((a) => a.target),
        values: actions.map((a) => a.value.toString()),
        calldatas: actions.map((a) => a.calldata),
        discourseURL: discourseURL || undefined,
        timestamp: Date.now(),
        crossChainExecution,
      }

      saveProposalToFile(proposalDetails, savePath)
    }

    // Submit to Tally API
    const response = await createTallyProposal(
      governorId,
      title,
      description,
      executableCalls,
      discourseURL,
    )

    // Get proposal ID and display URL
    const proposalId = response.data.createProposal.id
    console.log(kleur.green(`Tally proposal created successfully! ID: ${proposalId}`))
    const proposalUrl = formatTallyProposalUrl(governorId, proposalId)
    console.log(kleur.blue(`View your proposal at: ${proposalUrl}`))

    return proposalId
  } catch (error: any) {
    console.error(kleur.red('Error creating Tally draft proposal:'), error)
    if (
      error instanceof Error &&
      typeof error === 'object' &&
      error !== null &&
      'response' in error &&
      typeof (error as any).response === 'object'
    ) {
      console.error(kleur.red('Error response:'), (error as any).response.data)
    }

    // Define governorId in catch block as well
    const governorId = `eip155:${chainId}:${governorAddress}`

    // Fall back to showing manual submission details
    console.log(kleur.yellow('\nProposal details for manual submission:'))
    console.log(kleur.blue('Governor ID:'), kleur.cyan(governorId))
    console.log(kleur.blue('Targets:'), kleur.cyan(JSON.stringify(actions.map((a) => a.target))))
    console.log(
      kleur.blue('Values:'),
      kleur.cyan(actions.map((a) => a.value.toString()).join(', ')),
    )
    console.log(kleur.blue('Calldatas:'))
    actions.forEach((action) => {
      console.log(kleur.cyan(action.calldata))
    })
    console.log(kleur.blue('Description:'), kleur.cyan(description))

    // Save proposal details to JSON file even if Tally submission fails
    if (savePath) {
      try {
        const proposalDetails: ProposalDetails = {
          title,
          description,
          governorId,
          targets: actions.map((a) => a.target),
          values: actions.map((a) => a.value.toString()),
          calldatas: actions.map((a) => a.calldata),
          discourseURL: discourseURL || undefined,
          timestamp: Date.now(),
          crossChainExecution,
        }

        saveProposalToFile(proposalDetails, savePath)
      } catch (saveError) {
        console.error(kleur.red('Error saving proposal details:'), saveError)
      }
    }

    throw error
  }
}
