import dotenv from 'dotenv'
import { Address, Hex } from 'viem'

dotenv.config({ path: '../../.env' })

const TALLY_API_URL = 'https://api.tally.xyz/query'
const TALLY_API_KEY = process.env.TALLY_API_KEY

interface TallyExecutableCall {
  target: Address
  calldata: Hex | string
  signature: string
  value: string
  type: string
  offchaindata?: string
}

/**
 * Creates a draft proposal on Tally
 * @param governorId The governor ID in the format eip155:chainId:governorAddress
 * @param title The proposal title
 * @param description The proposal description in markdown format
 * @param executableCalls Array of executable calls for the proposal
 * @param discourseURL Optional URL to a Discourse discussion about the proposal
 * @returns The response from Tally API including the proposal ID
 */
export async function createTallyProposal(
  governorId: string,
  title: string,
  description: string,
  executableCalls: TallyExecutableCall[],
  discourseURL: string = '',
): Promise<any> {
  if (!TALLY_API_KEY) {
    throw new Error('TALLY_API_KEY environment variable is not set')
  }

  throw new Error('Tally api mutations not supported yet')

  const query = `
    mutation CreateTallyProposal($input: CreateProposalInput!) {
      createProposal(input: $input) {
        id
        metadata {
          txHash
        }
      }
    }
  `

  const variables = {
    input: {
      governorId,
      title,
      description,
      executableCalls,
      snapshotURL: '',
      discourseURL,
    },
  }

  console.log('Sending request to Tally API...')
  console.log('Governor ID:', governorId)
  console.log('Title:', title)
  console.log('Number of executable calls:', executableCalls.length)
  if (discourseURL) {
    console.log('Discourse URL:', discourseURL)
  }

  try {
    const response = await fetch(TALLY_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Api-Key': TALLY_API_KEY,
      },
      body: JSON.stringify({ query, variables }),
    })

    if (!response.ok) {
      throw new Error(`Tally API HTTP error: ${response.status} ${response.statusText}`)
    }

    const data = await response.json()

    if (data.errors) {
      throw new Error(`Tally API error: ${JSON.stringify(data.errors)}`)
    }

    return data
  } catch (error: any) {
    if (error.name === 'SyntaxError') {
      throw new Error('Failed to parse Tally API response')
    }
    throw error
  }
}

/**
 * Formats a Tally proposal URL from governor and proposal data
 * @param governorId The governor ID in the format eip155:chainId:governorAddress
 * @param proposalId The proposal ID from Tally
 * @returns The formatted URL to view the proposal on Tally
 */
export function formatTallyProposalUrl(governorId: string, proposalId: string): string {
  const [_, chainId, governorAddress] = governorId.split(':')
  return `https://www.tally.xyz/gov/${governorAddress}/proposal/${proposalId}?chainId=${chainId}`
}
