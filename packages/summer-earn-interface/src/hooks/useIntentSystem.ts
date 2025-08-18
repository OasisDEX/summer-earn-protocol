'use client'

import { useState, useEffect, useCallback } from 'react'
import { useAccount, usePublicClient, useWalletClient } from 'wagmi'
import { parseEther, formatEther, parseUnits, formatUnits } from 'viem'
import { IntentHandlerABI } from '../abis/IntentHandler'
import { IntentBondFactoryABI } from '../abis/IntentBondFactory'
import { GenericIntentArkABI } from '../abis/GenericIntentArk'
import { AaveV3EscrowABI } from '../abis/AaveV3Escrow'
import { erc20Abi } from '../abis/ERC20'
import { 
  INTENT_BOND_FACTORY_ADDRESSES, 
  INTENT_HANDLER_ADDRESSES, 
  GENERIC_INTENT_ARK_ADDRESSES,
  AAVE_V3_ESCROW_ADDRESSES,
  INTENT_SYSTEM_TOKENS
} from '../config/environments'
import type { Environment } from '../config/environments'
import type { ChainId } from '../types'

export interface IntentData {
  requiredNotional: bigint
  term: bigint
  targetYield: bigint
  token: string
  oracle: string
  expiry: bigint
  solver: string
  escrowedYield: bigint
  startTime: bigint
  state: number
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
  const genericIntentArk = GENERIC_INTENT_ARK_ADDRESSES[environment][chainId]
  const aaveV3Escrow = AAVE_V3_ESCROW_ADDRESSES[environment][chainId]
  const tokens = INTENT_SYSTEM_TOKENS[environment][chainId]

  const isDeployed = intentBondFactory !== '0x0000000000000000000000000000000000000000'

  // Get intent data for a user
  const getIntent = useCallback(async (userAddress: string) => {
    if (!publicClient || !intentHandler) return null
    
    try {
      const data = await publicClient.readContract({
        address: intentHandler as `0x${string}`,
        abi: IntentHandlerABI,
        functionName: 'getIntent',
        args: [userAddress as `0x${string}`]
      })
      
      return data as IntentData
    } catch (err) {
      console.error('Error getting intent:', err)
      return null
    }
  }, [publicClient, intentHandler])

  // Get solver information
  const getSolverInfo = useCallback(async (solverAddress: string) => {
    if (!publicClient || !intentBondFactory || !aaveV3Escrow) return null
    
    try {
      const [bondAmount, isVouched, totalAssets] = await Promise.all([
        publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'getSolverBondAmount',
          args: [solverAddress as `0x${string}`]
        }),
        publicClient.readContract({
          address: intentBondFactory as `0x${string}`,
          abi: IntentBondFactoryABI,
          functionName: 'isSolverVouched',
          args: [solverAddress as `0x${string}`, parseEther('1000')] // Check with 1000 token requirement
        }),
        publicClient.readContract({
          address: aaveV3Escrow as `0x${string}`,
          abi: AaveV3EscrowABI,
          functionName: 'totalAssets'
        })
      ])
      
      return {
        address: solverAddress,
        bondAmount,
        isVouched,
        totalAssets
      } as SolverInfo
    } catch (err) {
      console.error('Error getting solver info:', err)
      return null
    }
  }, [publicClient, intentBondFactory, aaveV3Escrow])

  // Create intent (keeper only)
  const createIntent = useCallback(async (
    intentId: string,
    requiredNotional: string,
    term: string,
    targetYield: string,
    summerToken: string,
    oracle: string,
    expiry: string
  ) => {
    if (!walletClient || !genericIntentArk || !userAddress) {
      throw new Error('Wallet not connected or contract not deployed')
    }

    setLoading(true)
    setError(null)

    try {
      const hash = await walletClient.writeContract({
        address: genericIntentArk as `0x${string}`,
        abi: GenericIntentArkABI,
        functionName: 'postIntent',
        args: [
          intentId as `0x${string}`,
          parseEther(requiredNotional),
          BigInt(term),
          parseEther(targetYield),
          summerToken as `0x${string}`,
          oracle as `0x${string}`,
          BigInt(expiry)
        ],
        chain: undefined,
        account: userAddress as `0x${string}`
      })

      return hash
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [walletClient, genericIntentArk, userAddress])

  // Solve intent (solver only)
  const solveIntent = useCallback(async (
    userAddress: string,
    solverAddress: string,
    escrowedYield: string
  ) => {
    if (!walletClient || !intentHandler) {
      throw new Error('Wallet not connected or contract not deployed')
    }

    setLoading(true)
    setError(null)

    try {
      const hash = await walletClient.writeContract({
        address: intentHandler as `0x${string}`,
        abi: IntentHandlerABI,
        functionName: 'solveIntent',
        args: [
          userAddress as `0x${string}`,
          solverAddress as `0x${string}`,
          parseEther(escrowedYield)
        ],
        chain: undefined,
        account: userAddress as `0x${string}`
      })

      return hash
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [walletClient, intentHandler])

  // Settle intent (solver only)
  const settleIntent = useCallback(async (userAddress: string) => {
    if (!walletClient || !intentHandler) {
      throw new Error('Wallet not connected or contract not deployed')
    }

    setLoading(true)
    setError(null)

    try {
      const hash = await walletClient.writeContract({
        address: intentHandler as `0x${string}`,
        abi: IntentHandlerABI,
        functionName: 'settleIntent',
        args: [userAddress as `0x${string}`],
        chain: undefined,
        account: userAddress as `0x${string}`
      })

      return hash
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [walletClient, intentHandler])

  // Create bond for solver
  const createBond = useCallback(async (solverAddress: string) => {
    if (!walletClient || !intentBondFactory) {
      throw new Error('Wallet not connected or contract not deployed')
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
        account: userAddress as `0x${string}`
      })

      return hash
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [walletClient, intentBondFactory])

  // Grant solver role
  const grantSolverRole = useCallback(async (solverAddress: string) => {
    if (!walletClient || !intentHandler) {
      throw new Error('Wallet not connected or contract not deployed')
    }

    setLoading(true)
    setError(null)

    try {
      const hash = await walletClient.writeContract({
        address: intentHandler as `0x${string}`,
        abi: IntentHandlerABI,
        functionName: 'grantSolverRole',
        args: [solverAddress as `0x${string}`],
        chain: undefined,
        account: userAddress as `0x${string}`
      })

      return hash
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [walletClient, intentHandler])

  // Add solver adapter
  const addSolverAdapter = useCallback(async (solverAddress: string, adapterAddress: string) => {
    if (!walletClient || !intentHandler) {
      throw new Error('Wallet not connected or contract not deployed')
    }

    setLoading(true)
    setError(null)

    try {
      const hash = await walletClient.writeContract({
        address: intentHandler as `0x${string}`,
        abi: IntentHandlerABI,
        functionName: 'addSolverAdapter',
        args: [solverAddress as `0x${string}`, adapterAddress as `0x${string}`],
        chain: undefined,
        account: userAddress as `0x${string}`
      })

      return hash
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [walletClient, intentHandler])

  // Load initial data
  useEffect(() => {
    if (!userAddress || !isDeployed) return

    const loadData = async () => {
      const intent = await getIntent(userAddress)
      setIntentData(intent)

      if (intent?.solver && intent.solver !== '0x0000000000000000000000000000000000000000') {
        const solver = await getSolverInfo(intent.solver)
        setSolverInfo(solver)
      }
    }

    loadData()
  }, [userAddress, isDeployed, getIntent, getSolverInfo])

  return {
    // State
    loading,
    error,
    intentData,
    solverInfo,
    isDeployed,
    
    // Contract addresses
    intentBondFactory,
    intentHandler,
    genericIntentArk,
    aaveV3Escrow,
    tokens,
    
    // Functions
    getIntent,
    getSolverInfo,
    createIntent,
    solveIntent,
    settleIntent,
    createBond,
    grantSolverRole,
    addSolverAdapter,
    
    // Utilities
    parseEther,
    formatEther,
    parseUnits,
    formatUnits
  }
}
