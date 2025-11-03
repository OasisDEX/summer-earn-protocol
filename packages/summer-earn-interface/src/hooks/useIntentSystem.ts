'use client'

import { useCallback, useEffect, useState } from 'react'
import { formatUnits, parseEther } from 'viem'
import { useAccount, usePublicClient, useWalletClient } from 'wagmi'

import { IntentBondFactoryABI } from '../abis/IntentBondFactory'
import { IntentHandlerABI } from '../abis/IntentHandler'
import type { Environment } from '../config/environments'
import {
  INTENT_BOND_FACTORY_ADDRESSES,
  INTENT_HANDLER_ADDRESSES,
  INTENT_SYSTEM_TOKENS,
  MOCK_INTENT_ORACLE_ADDRESSES,
} from '../config/environments'
import type { ChainId } from '../types'

export interface IntentData {
  user: string
  requiredNotional: bigint
  requiredBond: bigint
  term: bigint
  targetYield: bigint
  token: string
  oracle: string
  expiry: bigint
}

export interface SolverInfo {
  address: string
  bondAmount: bigint
  isVouched: boolean
  totalAssets: bigint
}

export interface IntentEvent {
  intentId: string
  user: string
  solver?: string
  state: string
  timestamp: number
  requiredNotional: bigint
  requiredBond: bigint
  term: bigint
  targetYield: bigint
  token: string
  expiry: bigint
}

type EventIntentStruct = IntentData & {
  [key: number]: unknown
}

export function useIntentSystem(environment: Environment, chainId: ChainId) {
  const { address: userAddress } = useAccount()
  const publicClient = usePublicClient()
  const { data: walletClient } = useWalletClient()

  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [solverInfo, setSolverInfo] = useState<SolverInfo | null>(null)
  const [intentEvents, setIntentEvents] = useState<IntentEvent[]>([])
  const [eventsLoading, setEventsLoading] = useState(false)

  // Contract addresses
  const intentBondFactory = INTENT_BOND_FACTORY_ADDRESSES[environment][chainId]
  const intentHandler = INTENT_HANDLER_ADDRESSES[environment][chainId]
  const mockIntentOracle = MOCK_INTENT_ORACLE_ADDRESSES[environment][chainId]
  const tokens = INTENT_SYSTEM_TOKENS[environment][chainId]

  const isDeployed = intentBondFactory !== '0x0000000000000000000000000000000000000000'

  // Get solver information
  const getSolverInfo = useCallback(
    async (solverAddress: string) => {
      if (!publicClient || !intentBondFactory) return null

      try {
        const [bondAmount, isVouched] = await Promise.all([
          // @ts-ignore
          publicClient.readContract({
            address: intentBondFactory as `0x${string}`,
            abi: IntentBondFactoryABI,
            functionName: 'getSolverBondAmount',
            args: [solverAddress as `0x${string}`],
          }),
          // @ts-ignore
          publicClient.readContract({
            address: intentBondFactory as `0x${string}`,
            abi: IntentBondFactoryABI,
            functionName: 'isSolverVouched',
            args: [solverAddress as `0x${string}`, parseEther('1000')], // Check with 1000 token requirement
          }),
        ])

        return {
          address: solverAddress,
          bondAmount: bondAmount as bigint,
          isVouched: isVouched as boolean,
          totalAssets: BigInt(0), // Not available in current implementation
        }
      } catch (err) {
        console.error('Error getting solver info:', err)
        return null
      }
    },
    [publicClient, intentBondFactory],
  )

  // Create a new intent
  const createIntent = useCallback(
    async (intent: IntentData) => {
      if (!walletClient || !intentHandler || !userAddress) {
        throw new Error('Missing required parameters')
      }

      setLoading(true)
      setError(null)

      try {
        const hash = await walletClient.writeContract({
          address: intentHandler as `0x${string}`,
          abi: IntentHandlerABI,
          functionName: 'createIntent',
          args: [intent],
          chain: undefined,
          account: userAddress as `0x${string}`,
        })

        return hash
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
        setError(errorMessage)
        throw err
      } finally {
        setLoading(false)
      }
    },
    [walletClient, intentHandler, userAddress],
  )

  // Solve an intent
  const solveIntent = useCallback(
    async (intent: IntentData, escrowedYield: bigint) => {
      if (!walletClient || !intentHandler || !userAddress) {
        throw new Error('Missing required parameters')
      }

      setLoading(true)
      setError(null)

      try {
        const hash = await walletClient.writeContract({
          address: intentHandler as `0x${string}`,
          abi: IntentHandlerABI,
          functionName: 'solveIntent',
          args: [intent, escrowedYield],
          chain: undefined,
          account: userAddress as `0x${string}`,
        })

        return hash
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
        setError(errorMessage)
        throw err
      } finally {
        setLoading(false)
      }
    },
    [walletClient, intentHandler, userAddress],
  )

  // Settle an intent
  const settleIntent = useCallback(
    async (intent: IntentData) => {
      if (!walletClient || !intentHandler || !userAddress) {
        throw new Error('Missing required parameters')
      }

      setLoading(true)
      setError(null)

      try {
        const hash = await walletClient.writeContract({
          address: intentHandler as `0x${string}`,
          abi: IntentHandlerABI,
          functionName: 'settleIntent',
          args: [intent],
          chain: undefined,
          account: userAddress as `0x${string}`,
        })

        return hash
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
        setError(errorMessage)
        throw err
      } finally {
        setLoading(false)
      }
    },
    [walletClient, intentHandler, userAddress],
  )

  // Create a solver bond
  const createBond = useCallback(
    async (solverAddress: string) => {
      if (!walletClient || !intentBondFactory || !userAddress) {
        throw new Error('Missing required parameters')
      }

      setLoading(true)
      setError(null)

      try {
        const hash = await walletClient.writeContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'createBond',
          args: [solverAddress as `0x${string}`],
          chain: undefined,
          account: userAddress as `0x${string}`,
        })

        return hash
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
        setError(errorMessage)
        throw err
      } finally {
        setLoading(false)
      }
    },
    [walletClient, intentBondFactory, userAddress],
  )

  // Add bond amount
  const addBond = useCallback(
    async (solverAddress: string, amount: bigint) => {
      if (!walletClient || !intentBondFactory || !userAddress) {
        throw new Error('Missing required parameters')
      }

      setLoading(true)
      setError(null)

      try {
        // First get the bond contract address
        const bondAddress = await // @ts-ignore
        publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'getSolverBond',
          args: [solverAddress as `0x${string}`],
        })

        if (!bondAddress || bondAddress === '0x0000000000000000000000000000000000000000') {
          throw new Error('Solver bond not found')
        }

        // First approve SUMMER tokens for the bond contract
        const summerTokenAddress = await // @ts-ignore
        publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'summerToken',
        })

        // Approve SUMMER tokens for the bond contract
        const approveHash = await walletClient.writeContract({
          address: summerTokenAddress as `0x${string}`,
          abi: [
            {
              inputs: [
                { name: 'spender', type: 'address' },
                { name: 'amount', type: 'uint256' },
              ],
              name: 'approve',
              outputs: [{ name: '', type: 'bool' }],
              stateMutability: 'nonpayable',
              type: 'function',
            },
          ],
          functionName: 'approve',
          args: [bondAddress as `0x${string}`, amount],
          chain: undefined,
          account: userAddress as `0x${string}`,
        })

        // Wait for approval to be mined
        await publicClient.waitForTransactionReceipt({ hash: approveHash })

        // Then add bond to the individual bond contract
        const hash = await walletClient.writeContract({
          address: bondAddress as `0x${string}`,
          abi: [
            {
              inputs: [{ name: 'amount', type: 'uint256' }],
              name: 'addBond',
              outputs: [],
              stateMutability: 'nonpayable',
              type: 'function',
            },
          ],
          functionName: 'addBond',
          args: [amount],
          chain: undefined,
          account: userAddress as `0x${string}`,
        })

        return hash
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
        setError(errorMessage)
        throw err
      } finally {
        setLoading(false)
      }
    },
    [walletClient, publicClient, intentBondFactory, userAddress],
  )

  // Check if solver is vouched
  const isSolverVouched = useCallback(
    async (solverAddress: string, requiredAmount: bigint) => {
      if (!publicClient || !intentBondFactory) return false

      try {
        const isVouched = await // @ts-ignore
        publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'isSolverVouched',
          args: [solverAddress as `0x${string}`, requiredAmount],
        })

        return isVouched as boolean
      } catch (err) {
        console.error('Error checking if solver is vouched:', err)
        return false
      }
    },
    [publicClient, intentBondFactory],
  )

  // Get solver bond amount
  const getSolverBondAmount = useCallback(
    async (solverAddress: string) => {
      if (!publicClient || !intentBondFactory) return BigInt(0)

      try {
        const bondAmount = await // @ts-ignore
        publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'getSolverBondAmount',
          args: [solverAddress as `0x${string}`],
        })

        return bondAmount as bigint
      } catch (err) {
        console.error('Error getting solver bond amount:', err)
        return BigInt(0)
      }
    },
    [publicClient, intentBondFactory],
  )

  // Check commitment status
  const hasCommitted = useCallback(
    async (intent: IntentData) => {
      if (!publicClient || !intentHandler) return null

      try {
        const result = await // @ts-ignore
        publicClient.readContract({
          address: intentHandler as `0x${string}`,
          abi: IntentHandlerABI,
          functionName: 'hasCommitted',
          args: [intent],
        })

        return result as [bigint, bigint, boolean]
      } catch (err) {
        console.error('Error checking commitment:', err)
        return null
      }
    },
    [publicClient, intentHandler],
  )

  // Fetch intent events
  const fetchIntentEvents = useCallback(async () => {
    if (!publicClient || !intentHandler) return

    setEventsLoading(true)
    try {
      // Get the latest 100 blocks
      const currentBlock = await publicClient.getBlockNumber()
      const fromBlock = currentBlock - BigInt(10000) // Look back 10,000 blocks

      // Fetch IntentCreated events
      const createdEvents = await publicClient.getLogs({
        address: intentHandler as `0x${string}`,
        event: {
          type: 'event',
          name: 'IntentCreated',
          inputs: [
            { type: 'bytes32', name: 'orderId', indexed: false },
            {
              type: 'tuple',
              name: 'intent',
              components: [
                { type: 'address', name: 'user' },
                { type: 'uint256', name: 'requiredNotional' },
                { type: 'uint256', name: 'requiredBond' },
                { type: 'uint256', name: 'term' },
                { type: 'uint256', name: 'targetYield' },
                { type: 'address', name: 'token' },
                { type: 'address', name: 'oracle' },
                { type: 'uint256', name: 'expiry' },
              ],
              indexed: false,
            },
          ],
        },
        fromBlock,
        toBlock: currentBlock,
      })

      // Fetch IntentSolved events
      const solvedEvents = await publicClient.getLogs({
        address: intentHandler as `0x${string}`,
        event: {
          type: 'event',
          name: 'IntentSolved',
          inputs: [
            { type: 'address', name: 'ark', indexed: true },
            { type: 'address', name: 'solver', indexed: true },
            { type: 'uint256', name: 'escrowedYield', indexed: false },
          ],
        },
        fromBlock,
        toBlock: currentBlock,
      })

      // Fetch IntentSettled events
      const settledEvents = await publicClient.getLogs({
        address: intentHandler as `0x${string}`,
        event: {
          type: 'event',
          name: 'IntentSettled',
          inputs: [
            { type: 'address', name: 'ark', indexed: true },
            { type: 'address', name: 'solver', indexed: true },
            { type: 'uint256', name: 'escrowedYield', indexed: false },
          ],
        },
        fromBlock,
        toBlock: currentBlock,
      })

      // Process and combine events
      const processedEvents: IntentEvent[] = []

      // Process created events
      for (const event of createdEvents) {
        const block = await publicClient.getBlock({ blockHash: event.blockHash! })
        const intentStruct = event.args.intent as EventIntentStruct

        processedEvents.push({
          intentId: event.args.orderId as string,
          user: intentStruct.user,
          state: 'Created',
          timestamp: Number(block.timestamp),
          requiredNotional: intentStruct.requiredNotional,
          requiredBond: intentStruct.requiredBond,
          term: intentStruct.term,
          targetYield: intentStruct.targetYield,
          token: intentStruct.token,
          expiry: intentStruct.expiry,
        })
      }

      // Process solved events and match with created events
      for (const event of solvedEvents) {
        const existingEvent = processedEvents.find((e) => e.user === event.args.ark && !e.solver)
        if (existingEvent) {
          existingEvent.solver = event.args.solver
          existingEvent.state = 'Solved'
        } else {
          // If we don't have the created event, add a minimal solved event
          const block = await publicClient.getBlock({ blockHash: event.blockHash! })
          processedEvents.push({
            intentId: 'unknown',
            user: event.args.ark as string,
            solver: event.args.solver as string,
            state: 'Solved',
            timestamp: Number(block.timestamp),
            requiredNotional: BigInt(0),
            requiredBond: BigInt(0),
            term: BigInt(0),
            targetYield: BigInt(0),
            token: 'unknown',
            expiry: BigInt(0),
          })
        }
      }

      // Process settled events
      for (const event of settledEvents) {
        const existingEvent = processedEvents.find(
          (e) => e.user === event.args.ark && e.solver === event.args.solver,
        )
        if (existingEvent) {
          existingEvent.state = 'Settled'
        }
      }

      // Sort by timestamp (most recent first)
      processedEvents.sort((a, b) => b.timestamp - a.timestamp)

      setIntentEvents(processedEvents)
    } catch (err) {
      console.error('Error fetching intent events:', err)
      setIntentEvents([])
    } finally {
      setEventsLoading(false)
    }
  }, [publicClient, intentHandler])

  // Check SUMMER token allowance for bond contract
  const getSummerTokenAllowance = useCallback(
    async (bondContractAddress: string) => {
      if (!publicClient || !intentBondFactory) return BigInt(0)

      try {
        const summerTokenAddress = await // @ts-ignore
        publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'summerToken',
        })

        const allowance = await // @ts-ignore
        publicClient.readContract({
          address: summerTokenAddress as `0x${string}`,
          abi: [
            {
              inputs: [
                { name: 'owner', type: 'address' },
                { name: 'spender', type: 'address' },
              ],
              name: 'allowance',
              outputs: [{ name: '', type: 'uint256' }],
              stateMutability: 'view',
              type: 'function',
            },
          ],
          functionName: 'allowance',
          args: [userAddress as `0x${string}`, bondContractAddress as `0x${string}`],
        })

        return allowance as bigint
      } catch (err) {
        console.error('Error checking SUMMER token allowance:', err)
        return BigInt(0)
      }
    },
    [publicClient, intentBondFactory, userAddress],
  )

  // Load initial data
  useEffect(() => {
    if (userAddress && isDeployed) {
      getSolverInfo(userAddress)
    }
  }, [userAddress, isDeployed, getSolverInfo])

  // Refresh solver info
  const refreshSolverInfo = useCallback(async () => {
    if (userAddress && isDeployed) {
      const info = await getSolverInfo(userAddress)
      if (info) {
        setSolverInfo(info)
      }
    }
  }, [userAddress, isDeployed, getSolverInfo])

  // Generic token approval function
  const approveToken = async (tokenAddress: string, spender: string, amount: bigint) => {
    if (!userAddress || !walletClient) {
      throw new Error('Wallet not connected')
    }

    try {
      const hash = await walletClient.writeContract({
        address: tokenAddress as `0x${string}`,
        abi: [
          {
            inputs: [
              { name: 'spender', type: 'address' },
              { name: 'amount', type: 'uint256' },
            ],
            name: 'approve',
            outputs: [{ name: '', type: 'bool' }],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ],
        functionName: 'approve',
        args: [spender as `0x${string}`, amount],
        chain: undefined,
        account: userAddress as `0x${string}`,
      })

      await publicClient.waitForTransactionReceipt({ hash })
      return hash
    } catch (error) {
      console.error('Error approving token:', error)
      throw error
    }
  }

  // Set price in mock oracle
  const setPrice = async (tokenAddress: string, price: bigint, decimals: number) => {
    if (!mockIntentOracle || !userAddress || !walletClient) {
      throw new Error('Mock oracle not available or wallet not connected')
    }

    try {
      const hash = await walletClient.writeContract({
        address: mockIntentOracle as `0x${string}`,
        abi: [
          {
            inputs: [
              { name: 'token', type: 'address' },
              { name: 'price', type: 'uint256' },
              { name: 'decimals', type: 'uint8' },
            ],
            name: 'setPrice',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ],
        functionName: 'setPrice',
        args: [tokenAddress as `0x${string}`, price, decimals],
        chain: undefined,
        account: userAddress as `0x${string}`,
      })

      await publicClient.waitForTransactionReceipt({ hash })
      return hash
    } catch (error) {
      console.error('Error setting price:', error)
      throw error
    }
  }

  return {
    loading,
    error,
    solverInfo,
    isDeployed,
    intentBondFactory,
    intentHandler,
    mockIntentOracle,
    tokens,
    intentEvents,
    eventsLoading,
    createIntent,
    solveIntent,
    settleIntent,
    createBond,
    addBond,
    isSolverVouched,
    getSolverBondAmount,
    hasCommitted,
    fetchIntentEvents,
    formatUnits,
    refreshSolverInfo,
    getSummerTokenAllowance,
    approveToken,
    setPrice,
  }
}
