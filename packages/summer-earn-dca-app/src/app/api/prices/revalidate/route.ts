import { updateTag } from 'next/cache'
import { isAddress } from 'viem'

// Shared-secret guarded invalidation. Wire from a Goldsky webhook on the
// `Execution` entity (or from a manual ops script) so freshly-executed
// strategies see the new round inside 5 min without waiting for the 300s
// `revalidate` window.
//
// Body: { chainId: number, token: `0x...`, range?: '7d'|'30d'|'90d'|'all' }
// If `range` is omitted, invalidate every range for the token.
export async function POST(request: Request): Promise<Response> {
  const secret = process.env.PRICE_REVALIDATE_SECRET
  if (!secret) {
    return Response.json({ error: 'not-configured' }, { status: 503 })
  }
  if (request.headers.get('authorization') !== `Bearer ${secret}`) {
    return Response.json({ error: 'unauthorized' }, { status: 401 })
  }

  let body: { chainId?: number; token?: string; range?: string }
  try {
    body = (await request.json()) as typeof body
  } catch {
    return Response.json({ error: 'invalid-json' }, { status: 400 })
  }

  const { chainId, token, range } = body
  if (typeof chainId !== 'number') {
    return Response.json({ error: 'invalid-chainId' }, { status: 400 })
  }
  if (!token || !isAddress(token)) {
    return Response.json({ error: 'invalid-token' }, { status: 400 })
  }

  if (range) {
    updateTag(`price:${chainId}:${token.toLowerCase()}:${range}`)
  } else {
    updateTag(`price:${chainId}:${token.toLowerCase()}`)
  }
  return Response.json({ ok: true })
}
