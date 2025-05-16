import { NextResponse } from 'next/server'

const SUBGRAPH_URL = 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base'

// Cache duration in seconds (15 minutes)
const CACHE_DURATION = 15 * 60

// In-memory cache
let cache: {
  data: any
  timestamp: number
} | null = null

export async function GET() {
  try {
    // Check if we have a valid cached response
    const now = Date.now()
    if (cache && now - cache.timestamp < CACHE_DURATION * 1000) {
      return NextResponse.json(cache.data)
    }

    const query = `
      {
        proposals {
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

    // Update cache
    cache = {
      data: data.data,
      timestamp: now,
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
