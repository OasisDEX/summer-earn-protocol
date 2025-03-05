import kleur from 'kleur'
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

/**
 * Creates a governance proposal using Tally API
 */
export async function createGovernanceProposal(
  title: string,
  description: string,
  actions: ProposalAction[],
  governorAddress: Address,
  chainId: number,
  discourseURL: string = '',
  actionSummary: string[] = [],
): Promise<string | undefined> {
  try {
    // Log proposal actions
    console.log(kleur.cyan('Creating Tally draft proposal with the following actions:'))
    if (actionSummary.length > 0) {
      actionSummary.forEach((action) => console.log(kleur.yellow(action)))
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

    throw error
  }
}
