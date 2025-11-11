/* eslint-disable @typescript-eslint/no-explicit-any */
// @ts-nocheck
import { useQuery } from '@tanstack/react-query'
import { erc20Abi, formatUnits } from 'viem'
import { multicall } from 'viem/actions'
import { usePublicClient } from 'wagmi'

import { CHAIN_NAMES } from '../config/chains'
import type {
  ArkRewardsData,
  ChainId,
  ChainRewardsData,
  ClaimableReward,
  FleetRewardsData,
  TokenBalance,
} from '../types'

// Configuration based on the Python script
const ARK_ACTIONS = {
  morpho: 'sweepAndStart',
  aave: 'sweepAndStart',
  euler: 'sweepAndStart',
  moonwell: 'harvestAndStart',
  gearbox: 'sweepAndStart',
  silo: 'harvestAndStart',
  SkyRewards: 'harvestAndStart',
  compound: 'harvestAndStart',
} as const

const ARK_TOKENS = {
  morpho: {
    1: [
      { address: '0x58D97B57BB95320F9a05dC918Aef65434969c2B2', threshold: 30 }, // MORPHO
      { address: '0x643C4E15d7d62Ad0aBeC4a9BD4b001aA3Ef52d66', threshold: 200 }, // syrup
    ],
    8453: [
      { address: '0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842', threshold: 50 }, // Base MORPHO
      { address: '0x1C7a460413dD4e964f96D8dFC56E7223cE88CD85', threshold: 500 }, // Base SEAM
      { address: '0xA88594D404727625A9437C3f886C7643872296AE', threshold: 2000 }, // Base WELL
    ],
  },
  aave: {
    146: [{ address: '0x6C5E14A212c1C3e4Baf6f871ac9B1a969918c131', threshold: 500 }], // aWS
  },
  euler: {
    146: [{ address: '0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38', threshold: 100 }], // wS
  },
  gearbox: {
    1: [
      { address: '0xBa3335588D9403515223F109EdC4eB7269a9Ab5D', threshold: 40000 },
      { address: '0xFa2B947eEc368f42195f24F36d2aF29f7c24CeC2', threshold: 1000 },
    ],
  },
} as const

const HARVEST_CONFIGS = {
  SkyRewards: {
    1: {
      contractAddress: '0x0650CAF159C5A49f711e8169D4336ECB9b950275',
      abi: [
        {
          inputs: [{ internalType: 'address', name: 'user', type: 'address' }],
          name: 'earned',
          outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      rewardThreshold: 100000000000000000000, // 100 tokens
    },
  },
  moonwell: {
    8453: {
      contractAddress: '0xe9005b078701e2A0948D2EaC43010D35870Ad9d2',
      abi: [
        {
          inputs: [
            { name: 'mToken', type: 'address' },
            { name: 'user', type: 'address' },
          ],
          name: 'getOutstandingRewardsForUser',
          outputs: [
            {
              components: [
                { internalType: 'address', name: 'emissionToken', type: 'address' },
                { internalType: 'uint256', name: 'totalAmount', type: 'uint256' },
                { internalType: 'uint256', name: 'supplySide', type: 'uint256' },
                { internalType: 'uint256', name: 'borrowSide', type: 'uint256' },
              ],
              internalType: 'struct MultiRewardDistributorCommon.RewardInfo[]',
              name: '',
              type: 'tuple[]',
            },
          ],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      arkData: {
        '0xe2ad084b9639ccc689217704577e538ca2c251e5': '0xb682c840B5F4FC58B20769E691A6fa1305A501a2',
        '0x07e33789cf837b52821c7cded1247938969008ef': '0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22',
      },
      rewardThreshold: 1000,
    },
  },
  silo: {
    146: {
      contractAddress: '0x2d3d269334485d2d876df7363e1a50b13220a7d8',
      abi: [
        {
          inputs: [
            { internalType: 'address', name: '_user', type: 'address' },
            { internalType: 'string[]', name: '_programNames', type: 'string[]' },
          ],
          name: 'getRewardsBalance',
          outputs: [{ name: 'unclaimedRewards', type: 'uint256' }],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      // todo: read all program names
      arkData: {
        '0x5c841955d7ee3e2f7a077aa0aca3a7d724b15da2': ['wS_sUSDC_0020'],
        '0x42aade02448fdaf56bbb153b2984e3d53dc531c1': ['wS_sUSDC_0008'],
        '0xf67e17c4627e9d9c150b247b6a4e82c01bf36c5f': ['xSILO_vUSDC1'],
        '0x39c5d327ff8b12649a0a8056ca4499cb27f82fa0': ['xSILO_aprUSDC_4th_batch'],
        '0x8faf711962e89047cb26fb4b4f8dbd578069db53': ['xSILO_ghUSDC'],
        '0x4c62fc0393393f3a5e455576bda95ccb3e284b19': ['SILO_re7USDC'],
      },
      rewardThreshold: 1000000000000000000000, // 1000 tokens
    },
  },
  compound: {
    1: {
      contractAddress: '0x1B0e765F6224C21223AeA2af16c1C46E38885a40',
      abi: [
        {
          inputs: [
            { internalType: 'address', name: 'comet', type: 'address' },
            { internalType: 'address', name: 'account', type: 'address' },
          ],
          name: 'getRewardOwed',
          outputs: [
            {
              components: [
                { internalType: 'address', name: 'token', type: 'address' },
                { internalType: 'uint256', name: 'owed', type: 'uint256' },
              ],
              internalType: 'struct RewardOwed',
              name: '',
              type: 'tuple',
            },
          ],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      arkData: {}, // Empty - will use ARK address as vault_id by default
      rewardThreshold: 2000000000000000000, // 2 tokens
    },
    8453: {
      contractAddress: '0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1',
      abi: [
        {
          inputs: [
            { internalType: 'address', name: 'comet', type: 'address' },
            { internalType: 'address', name: 'account', type: 'address' },
          ],
          name: 'getRewardOwed',
          outputs: [
            {
              components: [
                { internalType: 'address', name: 'token', type: 'address' },
                { internalType: 'uint256', name: 'owed', type: 'uint256' },
              ],
              internalType: 'struct RewardOwed',
              name: '',
              type: 'tuple',
            },
          ],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      arkData: {}, // Empty - will use ARK address as vault_id by default
      rewardThreshold: 2000000000000000000, // 2 tokens
    },
    42161: {
      contractAddress: '0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae',
      abi: [
        {
          inputs: [
            { internalType: 'address', name: 'comet', type: 'address' },
            { internalType: 'address', name: 'account', type: 'address' },
          ],
          name: 'getRewardOwed',
          outputs: [
            {
              components: [
                { internalType: 'address', name: 'token', type: 'address' },
                { internalType: 'uint256', name: 'owed', type: 'uint256' },
              ],
              internalType: 'struct RewardOwed',
              name: '',
              type: 'tuple',
            },
          ],
          stateMutability: 'view',
          type: 'function',
        },
      ],
      arkData: {}, // Empty - will use ARK address as vault_id by default
      rewardThreshold: 2000000000000000000, // 2 tokens
    },
  },
} as const

const MULTICALL_ADDRESSES = {
  1: '0xcA11bde05977b3631167028862bE2a173976CA11',
  8453: '0xcA11bde05977b3631167028862bE2a173976CA11',
  42161: '0xcA11bde05977b3631167028862bE2a173976CA11',
  146: '0x0000000000000000000000000000000000000000', // No multicall for Sonic
} as const

// Subgraph queries
const ARK_QUERY = `
  query GetArks {
    vaults {
      id
      arks(where: { name_not_contains_nocase: "BufferArk" }) {
        id
        name
        details
      }
    }
  }
`

interface SubgraphResponse {
  data: {
    vaults: Array<{
      id: string
      arks: Array<{
        id: string
        name: string
        details: string
      }>
    }>
  }
}

export function useRewardsData(chainId: ChainId) {
  const publicClient = usePublicClient({ chainId: parseInt(chainId) })

  return useQuery({
    queryKey: ['rewardsData', chainId],
    queryFn: async (): Promise<ChainRewardsData> => {
      if (!publicClient) throw new Error('No public client available')

      // Fetch ARKs from subgraph
      const subgraphUrl = `https://subgraph.staging.oasisapp.dev/summer-protocol${
        chainId === '1'
          ? ''
          : chainId === '8453'
            ? '-base'
            : chainId === '42161'
              ? '-arbitrum'
              : '-sonic'
      }`

      const response = await fetch(subgraphUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: ARK_QUERY }),
      })

      const data: SubgraphResponse = await response.json()

      if (!data.data?.vaults) {
        throw new Error('Failed to fetch ARKs from subgraph')
      }

      // Process ARKs and group by fleet (vault)
      const fleetMap = new Map<string, FleetRewardsData>()

      for (const vault of data.data.vaults) {
        const fleetAddress = vault.id
        const arks: ArkRewardsData[] = []

        for (const ark of vault.arks) {
          // Determine action type based on ARK name
          let actionType: 'sweepAndStart' | 'harvestAndStart' | 'none' = 'none'
          for (const [pattern, action] of Object.entries(ARK_ACTIONS)) {
            if (ark.name.toLowerCase().includes(pattern.toLowerCase())) {
              actionType = action as 'sweepAndStart' | 'harvestAndStart'
              break
            }
          }

          arks.push({
            address: ark.id,
            name: ark.name,
            details: ark.details,
            tokenBalances: [],
            claimableRewards: [],
            actionType,
          })
        }

        if (arks.length > 0) {
          fleetMap.set(fleetAddress, {
            address: fleetAddress,
            name: `Fleet ${fleetAddress.slice(0, 6)}...${fleetAddress.slice(-4)}`,
            symbol: 'FLEET',
            arks,
          })
        }
      }

      // Fetch token balances and rewards for each ARK
      const multicallAddress =
        MULTICALL_ADDRESSES[parseInt(chainId) as keyof typeof MULTICALL_ADDRESSES]

      for (const fleet of fleetMap.values()) {
        for (const ark of fleet.arks) {
          // Get token balances
          const tokenBalances = await getTokenBalances(
            publicClient,
            ark,
            parseInt(chainId),
            multicallAddress,
          )
          ark.tokenBalances = tokenBalances

          // Get claimable rewards
          const claimableRewards = await getClaimableRewards(publicClient, ark, parseInt(chainId))
          ark.claimableRewards = claimableRewards
        }
      }

      return {
        chainId,
        chainName: CHAIN_NAMES[chainId],
        fleets: Array.from(fleetMap.values()),
      }
    },
    enabled: !!publicClient,
    refetchInterval: 30000, // Refetch every 30 seconds
    staleTime: 10000, // Consider data stale after 10 seconds
  })
}

async function getTokenBalances(
  publicClient: any,
  ark: ArkRewardsData,
  chainId: number,
  multicallAddress: string,
): Promise<TokenBalance[]> {
  const tokenBalances: TokenBalance[] = []

  // Find tokens for this ARK based on its name
  const matchedPatterns = Object.keys(ARK_TOKENS).filter((pattern) =>
    ark.name.toLowerCase().includes(pattern.toLowerCase()),
  )

  if (matchedPatterns.length === 0) {
    return tokenBalances
  }

  const pattern = matchedPatterns[0] as keyof typeof ARK_TOKENS
  const chainTokens = ARK_TOKENS[pattern]?.[chainId as keyof (typeof ARK_TOKENS)[typeof pattern]]

  if (!chainTokens) {
    return tokenBalances
  }

  const tokens = chainTokens

  if (!tokens || multicallAddress === '0x0000000000000000000000000000000000000000') {
    // Fallback to individual calls for chains without multicall
    for (const token of tokens as Array<{ address: string; threshold: number }>) {
      try {
        const [symbol, decimals, balance] = await Promise.all([
          // @ts-ignore
          publicClient.readContract({
            address: token.address as `0x${string}`,
            abi: erc20Abi,
            functionName: 'symbol',
          }),
          // @ts-ignore
          publicClient.readContract({
            address: token.address as `0x${string}`,
            abi: erc20Abi,
            functionName: 'decimals',
          }),
          // @ts-ignore
          publicClient.readContract({
            address: token.address as `0x${string}`,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [ark.address as `0x${string}`],
          }),
        ])

        const balanceFormatted = parseFloat(formatUnits(balance, decimals))

        if (balanceFormatted > token.threshold) {
          tokenBalances.push({
            address: token.address,
            symbol,
            balance,
            balanceFormatted,
            decimals,
            threshold: token.threshold,
          })
        }
      } catch (error) {
        console.error(`Error fetching balance for token ${token.address}:`, error)
      }
    }
  } else {
    // Use multicall
    const calls = []

    for (const token of tokens as Array<{ address: string; threshold: number }>) {
      calls.push(
        {
          address: token.address as `0x${string}`,
          abi: erc20Abi,
          functionName: 'balanceOf',
          args: [ark.address as `0x${string}`],
        },
        {
          address: token.address as `0x${string}`,
          abi: erc20Abi,
          functionName: 'symbol',
        },
        {
          address: token.address as `0x${string}`,
          abi: erc20Abi,
          functionName: 'decimals',
        },
      )
    }

    try {
      const results = await multicall(publicClient, {
        contracts: calls as any,
        multicallAddress: multicallAddress as `0x${string}`,
        allowFailure: true,
      })

      const tokensArray = tokens as Array<{ address: string; threshold: number }>
      for (let i = 0; i < tokensArray.length; i++) {
        const balance = results[i * 3].result as bigint
        const symbol = results[i * 3 + 1].result as string
        const decimals = results[i * 3 + 2].result as number

        if (balance && symbol && decimals !== undefined) {
          const balanceFormatted = parseFloat(formatUnits(balance, decimals))

          if (balanceFormatted > tokensArray[i].threshold) {
            tokenBalances.push({
              address: tokensArray[i].address,
              symbol,
              balance,
              balanceFormatted,
              decimals,
              threshold: tokensArray[i].threshold,
            })
          }
        }
      }
    } catch (error) {
      console.error('Error in multicall for token balances:', error)
    }
  }

  return tokenBalances
}

// @ts-nocheck
async function getClaimableRewards(
  publicClient: any,
  ark: ArkRewardsData,
  chainId: number,
): Promise<ClaimableReward[]> {
  const claimableRewards: ClaimableReward[] = []

  // Find harvest config for this ARK
  const matchedPattern = Object.keys(HARVEST_CONFIGS).find((pattern) =>
    ark.name.toLowerCase().includes(pattern.toLowerCase()),
  )

  if (!matchedPattern) {
    return claimableRewards
  }

  const patternConfig = HARVEST_CONFIGS[matchedPattern as keyof typeof HARVEST_CONFIGS]
  // @ts-ignore - Type inference issue with complex nested types
  const config = patternConfig?.[chainId as keyof typeof patternConfig] as any

  if (!config) {
    return claimableRewards
  }

  try {
    let result: any

    if (matchedPattern === 'SkyRewards') {
      // @ts-ignore - Type inference issue with complex nested types
      result = await // @ts-ignore
      publicClient.readContract({
        address: config.contractAddress as `0x${string}`,
        abi: config.abi,
        functionName: 'earned',
        args: [ark.address as `0x${string}`],
      })
    } else if (matchedPattern === 'moonwell') {
      // @ts-ignore - Type inference issue with complex nested types
      const mTokenAddress = config.arkData?.[ark.address]
      if (!mTokenAddress) return claimableRewards

      // @ts-ignore - Type inference issue with complex nested types
      result = await // @ts-ignore
      publicClient.readContract({
        address: config.contractAddress as `0x${string}`,
        abi: config.abi,
        functionName: 'getOutstandingRewardsForUser',
        args: [mTokenAddress as `0x${string}`, ark.address as `0x${string}`],
      })
    } else if (matchedPattern === 'silo') {
      // @ts-ignore - Type inference issue with complex nested types
      const programNames = config.arkData?.[ark.address]
      if (!programNames) return claimableRewards

      // @ts-ignore - Type inference issue with complex nested types
      result = await // @ts-ignore
      publicClient.readContract({
        address: config.contractAddress as `0x${string}`,
        abi: config.abi,
        functionName: 'getRewardsBalance',
        args: [ark.address as `0x${string}`, programNames],
      })
    } else if (matchedPattern === 'compound') {
      // For Compound, first parameter is the comet address (vault_id)
      // Second parameter is the ARK address as the account
      // Since arkData is empty, we use ARK address as vault_id by default
      // @ts-ignore - Type inference issue with complex nested types
      //   const cometAddress = config.arkData?.[ark.address] || ark.address
      const parsedDetails = JSON.parse(ark.details)
      const cometAddress = parsedDetails.pool
      // @ts-ignore - Type inference issue with complex nested types
      result = await // @ts-ignore
      publicClient.readContract({
        address: config.contractAddress as `0x${string}`,
        abi: config.abi,
        functionName: 'getRewardOwed',
        args: [cometAddress as `0x${string}`, ark.address as `0x${string}`],
      })
    }

    if (result) {
      let amount: bigint
      let symbol: string
      let decimals: number

      if (matchedPattern === 'SkyRewards' || matchedPattern === 'silo') {
        amount = result as bigint
        symbol = matchedPattern === 'SkyRewards' ? 'SKY' : 'SILO'
        decimals = 18
      } else if (matchedPattern === 'moonwell') {
        // Process array of rewards
        for (const reward of result as any[]) {
          const tokenAddress = reward[0]
          const rewardAmount = reward[1]
          if (tokenAddress.toLowerCase() === '0xa88594d404727625a9437c3f886c7643872296ae') {
            amount = rewardAmount
            symbol = 'WELL'
            decimals = 18
            break
          }
        }
      } else if (matchedPattern === 'compound') {
        amount = result.owed as bigint

        symbol = 'COMP'
        decimals = 18
      }

      if (amount && amount > BigInt(0)) {
        const amountFormatted = parseFloat(formatUnits(amount, decimals))

        // @ts-ignore - Type inference issue with complex nested types

        claimableRewards.push({
          // @ts-ignore - Type inference issue with complex nested types
          contractAddress: config.contractAddress,
          amount,
          amountFormatted,
          symbol,
          decimals,
          // @ts-ignore - Type inference issue with complex nested types
          threshold: config.rewardThreshold / 1e18,
        })
      }
    }
  } catch (error) {
    console.error(`Error fetching claimable rewards for ARK ${ark.address}:`, error)
  }

  return claimableRewards
}
