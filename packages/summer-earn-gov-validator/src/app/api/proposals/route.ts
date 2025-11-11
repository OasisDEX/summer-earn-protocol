import { NextResponse } from 'next/server'

const SUBGRAPH_URL = 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base'

// Cache duration in seconds (5 minutes)
const CACHE_DURATION = 5 * 60

export async function GET() {
  try {
    const query = `
      {
        proposals(first:1000) {
          id
          description
          status
          targets
          values
          calldatas
        }
      }
    `

    const response = await fetch(SUBGRAPH_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query }),
      next: {
        revalidate: CACHE_DURATION,
      },
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Failed to fetch proposals: ${response.status} ${errorText}`)
    }

    const data = await response.json()
    if (data.errors) {
      throw new Error(data.errors[0].message)
    }

    if (!data.data || !data.data.proposals) {
      throw new Error('Invalid response format from subgraph')
    }

    return NextResponse.json(data.data)
  } catch (error) {
    console.error('Error fetching proposals:', error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'An error occurred' },
      { status: 500 },
    )
  }
}
