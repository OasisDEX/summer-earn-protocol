import { NextResponse } from 'next/server'

import { CHAINS } from '@/config/chains'
import deploymentConfigRaw from '@/config/index.json'
import { getCache, putCache } from '@/lib/dynamodb'
import { getSecret } from '@/lib/secrets'

const ACCOUNT_SLUG = 'oazoapps'
const PROJECT_SLUG = 'lazy-summer-governance-dashboard'

import { DeploymentConfig } from '@/types/deployment'

const deploymentConfig = deploymentConfigRaw as DeploymentConfig

import {
  Address,
  encodeAbiParameters,
  encodeFunctionData,
  formatEther,
  keccak256,
  parseAbiParameters,
  toHex,
} from 'viem'

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
    console.error('[SIMULATE] Failed to fetch TENDERLY_ACCESS_KEY:', e)
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
    const body = await req.json()
    const { actions, proposalId } = body as { actions: Action[]; proposalId?: string }

    if (!actions || actions.length === 0) {
      console.warn('[SIMULATE] No actions provided in the request.')
      return NextResponse.json({ error: 'No actions provided' }, { status: 400 })
    }

    // 1. Check DynamoDB Cache if proposalId is provided
    if (proposalId) {
      const cacheKey = `SIM#${proposalId}`
      const cached = await getCache<{ results: Record<string, TenderlyChainResult> }>(
        cacheKey,
        'RESULT',
      )
      if (cached) {
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
      if (!groupActions || groupActions.length === 0) {
        continue
      }

      const chainConfig = CHAINS.find((c) => c.id === chainId)
      if (!chainConfig || !chainConfig.tenderlyId) {
        console.warn(`[SIMULATE] Unsupported chain ID: ${chainId} (no tenderlyId found).`)
        results[chainId] = { error: 'Unsupported network for simulation' }
        continue
      }

      const chainData = deploymentConfig[chainConfig.key]
      const timelockAddress = chainData?.deployedContracts?.govV2?.timelock?.address
      const governorAddress = chainData?.deployedContracts?.govV2?.summerGovernor?.address

      if (!timelockAddress || !governorAddress) {
        console.error(
          `[SIMULATE] Failed to resolve contracts for chain ${chainId}. Timelock=${timelockAddress}, Governor=${governorAddress}`,
        )
        results[chainId] = { error: 'Timelock or Governor address not found for this chain' }
        continue
      }

      const publicClient = getPublicClient(Number(chainId))
      const balance = await publicClient.getBalance({ address: timelockAddress as Address })
      const balanceEther = formatEther(balance)

      // Generate Governor queue storage overrides if there are calls targeting the Governor contract
      const govStorage: Record<string, string> = {}
      const govActions = groupActions.filter(
        (a) => a.target.toLowerCase() === governorAddress.toLowerCase(),
      )

      if (govActions.length > 0) {
        const N = govActions.length

        // Slot 5 contains packed: uint128 _begin = 0, uint128 _end = N
        // Pack into 32 bytes (leftmost 16 bytes: _end, rightmost 16 bytes: _begin)
        const beginHex = '00000000000000000000000000000000'
        const endHex = BigInt(N).toString(16).padStart(32, '0')
        const slot5Value = `0x${endHex}${beginHex}`

        const slot5Key = '0x0000000000000000000000000000000000000000000000000000000000000005'
        govStorage[slot5Key] = slot5Value

        // Populate _data mapping slots (slot 6 is the mapping itself)
        govActions.forEach((action, i) => {
          const msgDataHash = keccak256(action.calldata as `0x${string}`)

          // Mapping slot for _data[i] at slot 6
          const mappingSlot = keccak256(
            encodeAbiParameters(parseAbiParameters('uint256, uint256'), [BigInt(i), 6n]),
          )

          govStorage[mappingSlot] = msgDataHash
        })
      }

      const stateObjects = {
        [timelockAddress]: {
          balance: toHex(balance),
        },
        [governorAddress]: {
          // Fund the governor contract with 100 ETH to ensure LayerZero messaging fees can be paid in the simulation
          balance: toHex(100n * 10n ** 18n),
          storage: govStorage,
        },
      }

      const targets = groupActions.map((a) => a.target as Address)
      const values = groupActions.map((a) => BigInt(a.value || '0'))
      const payloads = groupActions.map((a) => a.calldata as `0x${string}`)

      const salt = (groupActions[0]?.salt ||
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
          state_objects: stateObjects,
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
          state_objects: stateObjects,
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
          state_objects: stateObjects,
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
        console.error(`[SIMULATE] Tenderly API error on chain ${chainId}:`, err)
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
      for (let index = 0; index < simResults.length; index++) {
        const res = simResults[index]
        const simId = res.simulation?.id
        if (!simId) {
          console.warn(
            `[SIMULATE] No simulation ID found for transaction ${index + 1}. Skipping share call.`,
          )
          continue
        }

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
            const shareLink = `https://www.tdly.co/shared/simulation/${simId}`
            allShareLinks.push(shareLink)
          } else {
            console.error(`[SIMULATE] Tenderly share call failed with status: ${shareReq.status}`)
          }
        } catch (shareErr) {
          console.error(`[SIMULATE] Error sharing simulation ${simId}:`, shareErr)
        }
      }

      const shareUrls = allShareLinks
      const shareUrl =
        allShareLinks.length > 0 ? allShareLinks[allShareLinks.length - 1] : undefined

      // 4. Sanitize data to keep it under 400KB for DynamoDB and ensure consistency
      const sanitizedData: TenderlyChainResult = {
        balance: balanceEther,
        shareUrl,
        shareUrls,
        simulation_results: simResults.map((res, index) => {
          if (!res.transaction || !res.simulation) {
            console.warn(`[SIMULATE] Transaction or simulation object missing in result ${index}.`)
          }
          return {
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
          }
        }),
      }

      results[chainId] = sanitizedData
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
    console.error('[SIMULATE] Simulation API Internal Critical Error:', error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
