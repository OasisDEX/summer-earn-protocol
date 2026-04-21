import { NextResponse } from 'next/server'

import { CHAINS } from '@/config/chains'
import deploymentConfigRaw from '@/config/index.json'
import { getCache, putCache } from '@/lib/dynamodb'
import { getSecret } from '@/lib/secrets'

const ACCOUNT_SLUG = 'oazoapps'
const PROJECT_SLUG = 'lazy-summer-governance-dashboard'

import { DeploymentConfig } from '@/types/deployment'

const deploymentConfig = deploymentConfigRaw as DeploymentConfig

import { Address, encodeFunctionData, formatEther, toHex } from 'viem'

import { getPublicClient } from '@/config/rpc'
import { Action, TenderlyChainResult, TenderlyRawBundleResponse } from '@/types/tenderly'

const TIMELOCK_ABI = [
  {
    inputs: [{ name: 'newDelay', type: 'uint256' }],
    name: 'updateDelay',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'payloads', type: 'bytes[]' },
      { name: 'predecessor', type: 'bytes32' },
      { name: 'salt', type: 'bytes32' },
      { name: 'delay', type: 'uint256' },
    ],
    name: 'scheduleBatch',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'payloads', type: 'bytes[]' },
      { name: 'predecessor', type: 'bytes32' },
      { name: 'salt', type: 'bytes32' },
    ],
    name: 'executeBatch',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
] as const

// TODO: Successfully moved types to src/types/tenderly.ts

export async function POST(req: Request) {
  let tenderlyKey: string
  try {
    tenderlyKey = await getSecret('TENDERLY_ACCESS_KEY')
  } catch (e: unknown) {
    console.error('Failed to fetch TENDERLY_ACCESS_KEY:', e)
    return NextResponse.json(
      {
        error: 'TENDERLY_ACCESS_KEY fetch failed',
        details: (e as Error).message,
        code: (e as Error).name,
      },
      { status: 500 },
    )
  }

  try {
    const { actions, proposalId } = (await req.json()) as { actions: Action[]; proposalId?: string }

    // 1. Check DynamoDB Cache if proposalId is provided
    if (proposalId) {
      const cacheKey = `SIM#${proposalId}`
      const cached = await getCache<{ results: Record<string, TenderlyChainResult> }>(
        cacheKey,
        'RESULT',
      )
      if (cached) {
        console.log(`Serving cached simulation results for proposal ${proposalId}`)
        return NextResponse.json({ results: cached.results, source: 'cache' })
      }
    }

    // 2. Group actions by chain
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
      const governorAddress = chainData?.deployedContracts?.govV2?.summerGovernor?.address

      if (!timelockAddress || !governorAddress) {
        results[chainId] = { error: 'Timelock or Governor address not found for this chain' }
        continue
      }

      const publicClient = getPublicClient(Number(chainId))
      const balance = await publicClient.getBalance({ address: timelockAddress as Address })
      const balanceEther = formatEther(balance)

      const targets = groupActions.map((a) => a.target as Address)
      const values = groupActions.map((a) => BigInt(a.value || '0'))
      const payloads = groupActions.map((a) => a.calldata as `0x${string}`)
      const salt = (groupActions[0].salt ||
        '0x0000000000000000000000000000000000000000000000000000000000000000') as `0x${string}`
      const predecessor =
        '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`

      const simulations = [
        // 1. Update min delay to 0
        {
          network_id: chainConfig.tenderlyId,
          from: timelockAddress,
          to: timelockAddress,
          input: encodeFunctionData({
            abi: TIMELOCK_ABI,
            functionName: 'updateDelay',
            args: [0n],
          }),
          gas: 8000000,
          save: true,
          save_if_fails: true,
          simulation_type: 'abi',
          state_objects: {
            [timelockAddress]: {
              balance: toHex(balance),
            },
          },
        },
        // 2. Schedule the batch
        {
          network_id: chainConfig.tenderlyId,
          from: governorAddress,
          to: timelockAddress,
          input: encodeFunctionData({
            abi: TIMELOCK_ABI,
            functionName: 'scheduleBatch',
            args: [targets, values, payloads, predecessor, salt, 0n],
          }),
          gas: 8000000,
          save: true,
          save_if_fails: true,
          simulation_type: 'abi',
        },
        // 3. Execute the batch
        {
          network_id: chainConfig.tenderlyId,
          from: timelockAddress,
          to: timelockAddress,
          input: encodeFunctionData({
            abi: TIMELOCK_ABI,
            functionName: 'executeBatch',
            args: [targets, values, payloads, predecessor, salt],
          }),
          gas: 8000000,
          save: true,
          save_if_fails: true,
          simulation_type: 'abi',
          value: values.reduce((acc, v) => acc + v, 0n).toString(),
        },
      ]

      const response = await fetch(
        `https://api.tenderly.co/api/v1/account/${ACCOUNT_SLUG}/project/${PROJECT_SLUG}/simulate-bundle`,
        {
          method: 'POST',
          headers: {
            'X-Access-Key': tenderlyKey,
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
          balance: balanceEther,
        }
        continue
      }

      const rawData = (await response.json()) as TenderlyRawBundleResponse
      const simResults = rawData.simulation_results || []
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
                'X-Access-Key': tenderlyKey,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({}),
            },
          )

          if (shareReq.ok) {
            allShareLinks.push(`https://www.tdly.co/shared/simulation/${simId}`)
          }
        } catch (shareErr) {
          console.error(`Error sharing simulation ${simId}:`, shareErr)
        }
      }

      const shareUrls = allShareLinks
      const shareUrl = allShareLinks[allShareLinks.length - 1] // The EXECUTE transaction

      // 4. Sanitize data to keep it under 400KB for DynamoDB and ensure consistency
      const sanitizedData: TenderlyChainResult = {
        balance: balanceEther,
        shareUrl,
        shareUrls,
        simulation_results: simResults.map((res) => ({
          transaction: {
            hash: res.transaction?.hash,
            status: res.transaction?.status,
            gas_used: res.transaction?.gas_used,
            error_message: res.transaction?.error_message,
          },
          simulation: {
            id: res.simulation?.id,
            status: res.simulation?.status,
            gas_used: res.simulation?.gas_used,
            error_message: res.simulation?.error_message,
          },
        })),
      }

      results[chainId] = sanitizedData
      console.log(
        `Simulation successful for chain ${chainId}. Shared links created: ${allShareLinks.length}`,
      )
    }

    // 5. Save to DynamoDB Cache if proposalId is provided
    if (proposalId) {
      const cacheKey = `SIM#${proposalId}`
      await putCache(cacheKey, 'RESULT', {
        results,
        proposalId,
      })
    }

    return NextResponse.json({ results })
  } catch (err) {
    const error = err as Error
    console.error('Simulation API Internal Error:', error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
