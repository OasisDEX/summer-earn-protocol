import { NextResponse } from 'next/server'

import { CHAINS } from '@/config/chains'
import deploymentConfigRaw from '@/config/index.json'

const TENDERLY_ACCESS_KEY = process.env.TENDERLY_ACCESS_KEY
const ACCOUNT_SLUG = 'oazoapps'
const PROJECT_SLUG = 'lazy-summer-governance-dashboard'

import { DeploymentConfig } from '@/types/deployment'

const deploymentConfig = deploymentConfigRaw as DeploymentConfig

import { Address, formatEther, toHex } from 'viem'

import { getPublicClient } from '@/config/rpc'
import { Action, TenderlyChainResult } from '@/types/tenderly'

// TODO: Successfully moved types to src/types/tenderly.ts

export async function POST(req: Request) {
  if (!TENDERLY_ACCESS_KEY) {
    console.error('TENDERLY_ACCESS_KEY is not defined in environment variables')
    return NextResponse.json({ error: 'TENDERLY_ACCESS_KEY missing on server' }, { status: 500 })
  }

  try {
    const { actions } = (await req.json()) as { actions: Action[] }

    // 1. Group actions by chain
    const chainGroups = actions.reduce(
      (acc, action) => {
        acc[action.chainId] = acc[action.chainId] || []
        acc[action.chainId].push(action)
        return acc
      },
      {} as Record<string, Action[]>,
    )

    const results: Record<string, TenderlyChainResult | { error: string }> = {}

    // 2. Process each chain
    for (const [chainId, groupActions] of Object.entries(chainGroups)) {
      const chainConfig = CHAINS.find((c) => c.id === chainId)
      if (!chainConfig || !chainConfig.tenderlyId) {
        results[chainId] = { error: 'Unsupported network for simulation' }
        continue
      }

      const chainData = deploymentConfig[chainConfig.key]
      const timelockAddress = chainData?.deployedContracts?.govV2?.timelock?.address

      if (!timelockAddress) {
        results[chainId] = { error: 'Timelock address not found for this chain' }
        continue
      }

      const publicClient = getPublicClient(Number(chainId))
      const balance = await publicClient.getBalance({ address: timelockAddress as Address })
      const balanceEther = formatEther(balance)

      const simulations = groupActions.map((action) => ({
        network_id: chainConfig.tenderlyId,
        from: timelockAddress,
        to: action.target,
        input: action.calldata,
        gas: 8000000,
        save: true,
        save_if_fails: true,
        simulation_type: 'abi',
        state_objects: {
          [timelockAddress]: {
            balance: toHex(balance),
          },
        },
      }))

      const response = await fetch(
        `https://api.tenderly.co/api/v1/account/${ACCOUNT_SLUG}/project/${PROJECT_SLUG}/simulate-bundle`,
        {
          method: 'POST',
          headers: {
            'X-Access-Key': TENDERLY_ACCESS_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ simulations }),
        },
      )

      if (!response.ok) {
        const err = await response.text()
        console.error(`Tenderly API error on chain ${chainId}:`, err)
        results[chainId] = {
          error: `Tenderly API error: ${err}`,
          balance: balanceEther
        }
        continue
      }

      const data = (await response.json()) as TenderlyChainResult
      data.balance = balanceEther
      const simResults = data.simulation_results || []
      const allShareLinks: string[] = []

      // 3. Make EACH simulation public and get shared links
      for (const res of simResults) {
        const simId = res.simulation?.id
        if (!simId) continue

        try {
          const shareReq = await fetch(
            `https://api.tenderly.co/api/v1/account/${ACCOUNT_SLUG}/project/${PROJECT_SLUG}/simulations/${simId}/share`,
            {
              method: 'POST',
              headers: {
                'X-Access-Key': TENDERLY_ACCESS_KEY,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({}),
            }
          )

          if (shareReq.ok) {
            allShareLinks.push(`https://www.tdly.co/shared/simulation/${simId}`)
          }
        } catch (shareErr) {
          console.error(`Error sharing simulation ${simId}:`, shareErr)
        }
      }

      data.shareUrls = allShareLinks
      data.shareUrl = allShareLinks[0]
      console.log(data)
      results[chainId] = data
      console.log(`Simulation successful for chain ${chainId}. Shared links created: ${allShareLinks.length}`)
    }

    return NextResponse.json({ results })
  } catch (err) {
    const error = err as Error
    console.error('Simulation API Internal Error:', error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
