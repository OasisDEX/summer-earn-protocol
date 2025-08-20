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

export function useIntentSystem(environment: Environment, chainId: ChainId) {
  const { address: userAddress } = useAccount()
  const publicClient = usePublicClient()
  const { data: walletClient } = useWalletClient()

  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [intentData, setIntentData] = useState<IntentData | null>(null)
  const [solverInfo, setSolverInfo] = useState<SolverInfo | null>(null)

  // Contract addresses
  const intentBondFactory = INTENT_BOND_FACTORY_ADDRESSES[environment][chainId]
  const intentHandler = INTENT_HANDLER_ADDRESSES[environment][chainId]
  const mockIntentOracle = MOCK_INTENT_ORACLE_ADDRESSES[environment][chainId]
  const tokens = INTENT_SYSTEM_TOKENS[environment][chainId]

  const isDeployed = intentBondFactory !== '0x0000000000000000000000000000000000000000'

  // Get intent data for a user
  const getIntent = useCallback(
    async (userAddress: string) => {
      // This function doesn't exist in the current contract
      // Intents are created and managed differently
      console.log('getIntent not implemented in current contract')
      return null
    },
    [publicClient, intentHandler],
  )

  // Get solver information
  const getSolverInfo = useCallback(
    async (solverAddress: string) => {
      if (!publicClient || !intentBondFactory) return null

      try {
        const [bondAmount, isVouched] = await Promise.all([
          publicClient.readContract({
            address: intentBondFactory as `0x${string}`,
            abi: IntentBondFactoryABI,
            functionName: 'getSolverBondAmount',
            args: [solverAddress as `0x${string}`],
          }),
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
        const bondAddress = await publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'getSolverBond',
          args: [solverAddress as `0x${string}`],
        })

        if (!bondAddress || bondAddress === '0x0000000000000000000000000000000000000000') {
          throw new Error('Solver bond not found')
        }

        // First approve SUMMER tokens for the bond contract
        const summerTokenAddress = await publicClient.readContract({
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
        const isVouched = await publicClient.readContract({
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
        const bondAmount = await publicClient.readContract({
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
        const result = await publicClient.readContract({
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

  // Check SUMMER token allowance for bond contract
  const getSummerTokenAllowance = useCallback(
    async (bondContractAddress: string) => {
      if (!publicClient || !intentBondFactory) return BigInt(0)

      try {
        const summerTokenAddress = await publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'summerToken',
        })

        const allowance = await publicClient.readContract({
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
      // Don't call getIntent since it's not implemented
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

  return {
    loading,
    error,
    intentData,
    solverInfo,
    isDeployed,
    intentBondFactory,
    intentHandler,
    mockIntentOracle,
    tokens,
    createIntent,
    solveIntent,
    settleIntent,
    createBond,
    addBond,
    isSolverVouched,
    getSolverBondAmount,
    hasCommitted,
    formatUnits,
    refreshSolverInfo,
    getSummerTokenAllowance,
  }
}
