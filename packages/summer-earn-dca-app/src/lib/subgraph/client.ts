import { CHAIN_DCA_SUBGRAPH_URLS } from '@/config/chains'
import type { ChainId } from '@/types/chain'

interface GqlResponse<T> {
  data?: T
  errors?: Array<{ message: string }>
}

export async function gqlFetch<T>(
  chainId: ChainId,
  query: string,
  variables: Record<string, unknown> = {},
): Promise<T> {
  const url = CHAIN_DCA_SUBGRAPH_URLS[chainId]

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, variables }),
    cache: 'no-store',
  })

  if (!response.ok) {
    throw new Error(`Subgraph request failed: ${response.status} ${response.statusText}`)
  }

  const body = (await response.json()) as GqlResponse<T>
  if (body.errors && body.errors.length > 0) {
    throw new Error(`Subgraph error: ${body.errors.map((e) => e.message).join('; ')}`)
  }
  if (!body.data) {
    throw new Error('Subgraph returned no data')
  }
  return body.data
}
