import { getCachedOrFetch } from '@/lib/dynamodb'
import { getSecret } from '@/lib/secrets'
import { CuriaDelegateStats } from '@/types/governance'

/**
 * CuriaLab (api.curiahub.xyz) delegate analytics for the delegates page.
 *
 * Three bulk endpoints are combined into one per-address record:
 *  - /daos/{dao}/metrics/delegate_participation — participation metrics per delegate
 *  - /daos/{dao}/socials — maps delegate addresses to Discourse usernames
 *  - /daos/{dao}/prs/{start}/{end} — per-forum-post reputation scores by username
 *
 * The PRS shown per delegate is the sum of `normalized_score` over the last year of
 * their forum posts, joined address→discourse-username via the socials endpoint.
 *
 * Requires the CURIA_API_KEY secret (env locally, SSM on Amplify). Without a key the
 * service quietly returns no data and the UI omits the Curia stats. Results are
 * cached in DynamoDB for a day (see getCuriaDelegates) so the page never blocks on
 * the Curia API.
 */

const CURIA_API_BASE = 'https://api.curiahub.xyz'
const DAO_SLUG = process.env.CURIA_DAO_SLUG || 'summer'
const PRS_WINDOW_DAYS = 365
const CACHE_TTL_SECONDS = 24 * 60 * 60 // one day, per team decision

interface CuriaParticipationRow {
  address: string
  ens: string | null
  status: string
  voting_power: number
  delegator_count: number
  percent_of_voting_power: number
  votes: number
  proposals_count: number
  recent_votes: number
}

interface CuriaSocialRow {
  address: string
  source: 'twitter' | 'discord' | 'discourse' | 'telegram'
  username: string
}

interface CuriaPrsRow {
  topic_id: number
  post_number: number
  user_name: string
  normalized_score: number
  raw_score: number
}

// Shape lives in types/governance.ts (CuriaDelegateStats) so client components can
// use it without importing this server-only module. `prsScore` is the sum of
// normalized per-post PRS over the last year; null when the delegate has no linked
// Discourse account or no scored posts in the window.
export type CuriaDelegateData = CuriaDelegateStats

async function curiaFetch(apiKey: string, path: string): Promise<unknown> {
  const response = await fetch(`${CURIA_API_BASE}${path}`, {
    headers: { accept: 'application/json', 'x-api-key': apiKey },
  })
  if (!response.ok) {
    throw new Error(`Curia API ${path} failed with status ${response.status}`)
  }
  return response.json()
}

// The (beta) API wraps some list payloads in an envelope object instead of returning
// a bare array. Accept either: a bare array, one of the expected envelope keys, or —
// as a last resort — the first array-valued property. Logs the keys when nothing
// matches so the real shape shows up in the server logs instead of a TypeError.
function unwrapArray<T>(payload: unknown, ...candidateKeys: string[]): T[] {
  if (Array.isArray(payload)) return payload as T[]
  if (payload && typeof payload === 'object') {
    const record = payload as Record<string, unknown>
    for (const key of candidateKeys) {
      if (Array.isArray(record[key])) return record[key] as T[]
    }
    const firstArray = Object.values(record).find(Array.isArray)
    if (firstArray) return firstArray as T[]
    console.error('Curia API returned an unexpected object shape; keys:', Object.keys(record))
    return []
  }
  console.error('Curia API returned a non-list payload of type:', typeof payload)
  return []
}

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10)
}

async function getCuriaApiKey(): Promise<string> {
  try {
    return (await getSecret('CURIA_API_KEY')) || ''
  } catch {
    return ''
  }
}

async function fetchCuriaDelegatesFromApi(
  apiKey: string,
): Promise<Record<string, CuriaDelegateData>> {
  const end = new Date()
  const start = new Date(end.getTime() - PRS_WINDOW_DAYS * 24 * 60 * 60 * 1000)

  // Participation metrics are the core payload; socials/PRS only enrich it, so their
  // failures degrade to prsScore: null instead of failing the whole fetch.
  const [participationRaw, socialsRaw, prsRaw] = await Promise.all([
    curiaFetch(apiKey, `/daos/${DAO_SLUG}/metrics/delegate_participation`),
    curiaFetch(apiKey, `/daos/${DAO_SLUG}/socials`).catch((error) => {
      console.error('Curia socials fetch failed:', error)
      return []
    }),
    curiaFetch(apiKey, `/daos/${DAO_SLUG}/prs/${isoDate(start)}/${isoDate(end)}`).catch((error) => {
      console.error('Curia PRS fetch failed:', error)
      return []
    }),
  ])

  const participation = unwrapArray<CuriaParticipationRow>(
    participationRaw,
    'data',
    'delegates',
    'delegate_participation',
    'result',
  )
  const socials = unwrapArray<CuriaSocialRow>(socialsRaw, 'data', 'socials', 'profiles', 'result')
  const prsRows = unwrapArray<CuriaPrsRow>(prsRaw, 'data', 'prs', 'scores', 'result')

  // Discourse usernames are case-insensitive; normalize both sides of the join.
  const addressByUsername = new Map<string, string>()
  for (const social of socials) {
    if (social.source === 'discourse' && social.username) {
      addressByUsername.set(social.username.toLowerCase(), social.address.toLowerCase())
    }
  }

  const prsByAddress = new Map<string, number>()
  for (const row of prsRows) {
    const address = addressByUsername.get(row.user_name?.toLowerCase() ?? '')
    if (!address) continue
    prsByAddress.set(address, (prsByAddress.get(address) ?? 0) + (row.normalized_score || 0))
  }

  const result: Record<string, CuriaDelegateData> = {}
  for (const row of participation) {
    const address = row.address.toLowerCase()
    const prs = prsByAddress.get(address)
    result[address] = {
      prsScore: prs !== undefined ? Math.round(prs * 10) / 10 : null,
      votesCast: row.votes ?? 0,
      proposalsCount: row.proposals_count ?? 0,
      recentVotes: row.recent_votes ?? 0,
      delegatorCount: row.delegator_count ?? 0,
      percentOfVotingPower: row.percent_of_voting_power ?? 0,
    }
  }

  return result
}

// DynamoDB-cached entry point (1-day TTL, stale-on-error). Returns an empty map when
// both the cache and the API are unavailable so the delegates page still renders.
// The key check happens BEFORE the cache so an unconfigured deployment never caches
// an empty result — the data appears on the first render after the key is added.
export async function getCuriaDelegates(): Promise<Record<string, CuriaDelegateData>> {
  const apiKey = await getCuriaApiKey()
  if (!apiKey) {
    // No key configured — the feature is simply off.
    return {}
  }

  const cached = await getCachedOrFetch('curia', `delegates:${DAO_SLUG}`, CACHE_TTL_SECONDS, () =>
    fetchCuriaDelegatesFromApi(apiKey),
  )
  return cached ?? {}
}
