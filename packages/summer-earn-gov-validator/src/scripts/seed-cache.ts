import { loadEnvConfig } from '@next/env'
loadEnvConfig(process.cwd())

import fs from 'fs'
import path from 'path'
import { isAddress } from 'viem'

import { CHAINS } from '../config/chains'
import deploymentConfig from '../config/index.json'
import { BLOCKSCOUT_APIS, fetchAbi, getImplementationAddress } from '../lib/abi'
import { getCache, putCache } from '../lib/dynamodb'

const DEPLOYED_DIR = path.join(process.cwd(), 'src/config/deployed')
const DELAY_MS = 200 // 5 requests per second

// 1. Identify all chainId -> networkKey mapping
const NETWORK_KEY_TO_CHAIN_ID: Record<string, string> = {}
CHAINS.forEach((c) => {
  NETWORK_KEY_TO_CHAIN_ID[c.key] = c.id
})

async function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function seed() {
  console.log('🚀 Starting ABI Cache Seeding...')

  const toProcess: { chainId: string; address: string }[] = []

  // --- Source 1: src/config/index.json ---
  console.log('📦 Parsing src/config/index.json...')
  Object.entries(deploymentConfig).forEach(([networkKey, data]: [string, unknown]) => {
    const chainId = NETWORK_KEY_TO_CHAIN_ID[networkKey]
    if (!chainId) return

    // Deep search for "address" keys
    const findAddresses = (obj: unknown) => {
      if (!obj || typeof obj !== 'object') return
      Object.entries(obj).forEach(([key, value]) => {
        if (key === 'address' && typeof value === 'string' && isAddress(value)) {
          toProcess.push({ chainId, address: value })
        } else if (typeof value === 'string' && isAddress(value)) {
          // Also catch direct token mappings etc
          toProcess.push({ chainId, address: value })
        } else {
          findAddresses(value)
        }
      })
    }
    findAddresses(data)
  })

  // --- Source 2: src/config/deployed/*.json ---
  if (fs.existsSync(DEPLOYED_DIR)) {
    console.log(`📂 Parsing src/config/deployed/*.json...`)
    const files = fs.readdirSync(DEPLOYED_DIR)
    files.forEach((file) => {
      if (!file.endsWith('.json')) return
      const networkKey = file.replace('.json', '')
      const chainId = NETWORK_KEY_TO_CHAIN_ID[networkKey]
      if (!chainId) {
        console.warn(`⚠️  Unknown network key in filename: ${file}`)
        return
      }

      const content = JSON.parse(fs.readFileSync(path.join(DEPLOYED_DIR, file), 'utf-8'))
      Object.values(content).forEach((value) => {
        if (typeof value === 'string' && isAddress(value)) {
          toProcess.push({ chainId, address: value })
        }
      })
    })
  }

  // Deduplicate
  const uniquePairs = Array.from(
    new Set(toProcess.map((p) => `${p.chainId}:${p.address.toLowerCase()}`)),
  ).map((p) => {
    const [chainId, address] = p.split(':')
    return { chainId, address }
  })

  console.log(`🎯 Found ${uniquePairs.length} unique contract addresses to check.`)

  let successCount = 0
  let skipCount = 0
  let errorCount = 0

  for (const item of uniquePairs) {
    const { chainId, address } = item
    const cacheKey = `ABI#${chainId}#${address}`

    try {
      // 1. Check if already cached (Skip if requested)
      const cached = await getCache(cacheKey, 'DATA')
      if (cached) {
        skipCount++
        continue
      }

      const apiUrl = BLOCKSCOUT_APIS[chainId]
      if (!apiUrl) {
        // console.warn(`⚠️  No explorer for chain ${chainId} (${address})`)
        continue
      }

      const apiKey = process.env.BLOCKSCOUT_API_KEY

      // 2. Fetch
      let addressToFetch = address
      const implementationAddress = await getImplementationAddress(apiUrl, address, apiKey)
      if (implementationAddress) {
        addressToFetch = implementationAddress
      }

      const abi = await fetchAbi(apiUrl, addressToFetch, apiKey)

      // 3. Save
      const success = await putCache(cacheKey, 'DATA', {
        abi,
        chainId,
        address,
        ...(addressToFetch !== address && { implementationAddress: addressToFetch }),
      })

      if (success) {
        successCount++
        console.log(`✅ Cached [${chainId}] ${address}`)
      } else {
        errorCount++
      }

      // Throttle
      await sleep(DELAY_MS)
    } catch (err) {
      errorCount++
      console.error(`❌ Failed [${chainId}] ${address}:`, (err as Error).message)
    }
  }

  console.log('\n✨ Seeding Complete!')
  console.log(`✅ Success: ${successCount}`)
  console.log(`⏩ Skipped: ${skipCount}`)
  console.log(`❌ Errors: ${errorCount}`)
}

seed().catch(console.error)
