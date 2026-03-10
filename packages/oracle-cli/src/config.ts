import path from 'path'
import { config } from 'dotenv'
import { z } from 'zod'
import { base, arbitrum, mainnet, sonic, type Chain } from 'viem/chains'

// Load env: root first, then package local
config({ path: path.resolve(process.cwd(), '../../.env') })
config({ path: path.resolve(process.cwd(), '.env') })

/** Supported deploy networks */
export type DeployNetwork = 'base' | 'arbitrum' | 'mainnet' | 'sonic'

/** Network -> viem chain (no ternary chain) */
const VIEM_CHAINS: Record<DeployNetwork, Chain> = {
  base,
  arbitrum,
  mainnet,
  sonic,
}

export function getChain(network: DeployNetwork): Chain {
  const chain = VIEM_CHAINS[network]
  if (!chain) {
    throw new Error(`Unknown network: ${network}. Supported: base, arbitrum, mainnet, sonic`)
  }
  return chain
}

const RPC_ENV_KEYS: Record<DeployNetwork, string> = {
  base: 'BASE_RPC_URL',
  arbitrum: 'ARBITRUM_RPC_URL',
  mainnet: 'MAINNET_RPC_URL',
  sonic: 'SONIC_RPC_URL',
}

/** Env keys to check (in order); base also accepts RPC_URL for backward compat */
const RPC_ENV_CANDIDATES: Record<DeployNetwork, string[]> = {
  base: ['BASE_RPC_URL', 'RPC_URL'],
  arbitrum: ['ARBITRUM_RPC_URL'],
  mainnet: ['MAINNET_RPC_URL'],
  sonic: ['SONIC_RPC_URL'],
}

const UrlSchema = z.url()

/**
 * Returns validated RPC URL for the given network.
 * Throws with clear error if env var is missing or invalid.
 */
export function getRpcUrl(network: 'base' | 'arbitrum' | 'mainnet' | 'sonic'): string {
  const key = RPC_ENV_KEYS[network]
  const candidates = RPC_ENV_CANDIDATES[network]
  const raw = candidates.map((k) => process.env[k]).find((v) => v && v.trim() !== '')

  if (!raw) {
    const hint = candidates.join(' or ')
    throw new Error(`${key} is required but not set. Configure ${hint} in .env`)
  }

  const result = UrlSchema.safeParse(raw)
  if (!result.success) {
    throw new Error(`${key} must be a valid URL. Received: ${raw}`)
  }

  return result.data
}

const WTConfigSchema = z.object({
  WT_CLIENT: z.string().min(1),
  WT_SECRET: z.string().min(1),
  WT_LOGIN: z.string().min(1),
  WT_PASSWORD: z.string().min(1),
})

export function getWTConfig() {
  const result = WTConfigSchema.safeParse(process.env)
  if (!result.success) {
    throw new Error(`WisdomTree Connect configuration is incomplete: ${result.error.message}`)
  }
  return result.data
}
