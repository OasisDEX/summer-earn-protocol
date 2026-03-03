'use client'

import { useState } from 'react'
import { type Address, type Hex, encodeFunctionData, getAddress } from 'viem'
import {
  useSignTypedData,
  useWriteContract,
  useConnection,
  useSwitchChain,
  usePublicClient,
} from 'wagmi'
import { toast } from 'sonner'
import { RWA_ORACLE_ABI } from '../lib/constants'
import { invalidateActivityLog } from '../app/actions/revalidate'

// Multicall3 ABI for aggregate3
const MULTICALL3_ABI = [
  {
    inputs: [
      {
        components: [
          { name: 'target', type: 'address' },
          { name: 'allowFailure', type: 'bool' },
          { name: 'callData', type: 'bytes' },
        ],
        name: 'calls',
        type: 'tuple[]',
      },
    ],
    name: 'aggregate3',
    outputs: [
      {
        components: [
          { name: 'success', type: 'bool' },
          { name: 'returnData', type: 'bytes' },
        ],
        name: 'returnData',
        type: 'tuple[]',
      },
    ],
    stateMutability: 'payable',
    type: 'function',
  },
] as const

const MULTICALL3_ADDRESS = getAddress('0xcA11bde05977b3631167028862bE2a173976CA11')

/** EIP-712 types for RwaOracle price update - must match contract */
const PRICE_UPDATE_TYPES = {
  PriceUpdate: [
    { name: 'price', type: 'int256' },
    { name: 'timestamp', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'oracle', type: 'address' },
    { name: 'chainId', type: 'uint256' },
  ],
} as const

export interface OracleUpdateData {
  ticker: string
  oracleAddress: Address
  onChainPrice: number
  offChainPrice: number
}

interface BatchUpdateModalProps {
  isOpen: boolean
  onClose: () => void
  oracles: OracleUpdateData[]
  chainId: number
}

export function BatchUpdateModal({ isOpen, onClose, oracles, chainId }: BatchUpdateModalProps) {
  const { address, chain: currentChain } = useConnection()
  const { mutateAsync: switchChainAsync } = useSwitchChain()
  const { mutateAsync: signTypedDataAsync } = useSignTypedData()
  const { mutateAsync: writeContractAsync } = useWriteContract()
  const publicClient = usePublicClient()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [currentStep, setCurrentStep] = useState(0) // 0: idle, 1: fetching nonces, 2: signing, 3: submitting

  if (!isOpen) return null

  const handleBatchUpdate = async () => {
    if (!address) {
      toast.error('Please connect your wallet first')
      return
    }

    if (!publicClient) {
      toast.error('Public client not initialized')
      return
    }

    setIsSubmitting(true)
    setCurrentStep(1)

    try {
      // 1. Ensure correct chain
      if (currentChain?.id !== chainId) {
        toast.info(`Switching to the correct network...`)
        await switchChainAsync({ chainId })
      }

      // 2. Fetch nonces for all oracles
      toast.info('Fetching nonces...')
      const nonceCalls = oracles.map((o) => ({
        address: o.oracleAddress,
        abi: RWA_ORACLE_ABI,
        functionName: 'nonce',
      }))

      // Use multicall to get all nonces
      const nonceResults = await publicClient.multicall({
        contracts: nonceCalls,
        allowFailure: true,
      })

      // 3. Collect signatures
      setCurrentStep(2)
      const signatures: {
        oracle: Address
        signature: Hex
        price: bigint
        timestamp: bigint
        nonce: bigint
      }[] = []

      const timestamp = BigInt(Math.floor(Date.now() / 1000))

      for (let i = 0; i < oracles.length; i++) {
        const oracle = oracles[i]

        if (oracle.offChainPrice <= 0) {
          toast.warning(`Skipping ${oracle.ticker}: Invalid price (0)`)
          continue
        }

        const nonceResult = nonceResults[i]
        if (nonceResult.status !== 'success') {
          toast.error(`Failed to fetch nonce for ${oracle.ticker}`)
          continue
        }

        const nonce = nonceResult.result as bigint
        const price = BigInt(Math.round(oracle.offChainPrice * 10 ** 8))

        toast.info(`Sign update for ${oracle.ticker} (${i + 1}/${oracles.length})`)

        const signature = await signTypedDataAsync({
          domain: {
            name: 'RwaOracle',
            version: '1',
            chainId,
            verifyingContract: oracle.oracleAddress,
          },
          types: PRICE_UPDATE_TYPES,
          primaryType: 'PriceUpdate',
          message: {
            price,
            timestamp,
            nonce,
            oracle: oracle.oracleAddress,
            chainId: BigInt(chainId),
          },
        })

        signatures.push({
          oracle: oracle.oracleAddress,
          signature,
          price,
          timestamp,
          nonce,
        })
      }

      // 4. Batch Submit via Multicall3
      setCurrentStep(3)
      toast.info('Confirm batch transaction...')

      const calls = signatures.map((s) => ({
        target: s.oracle,
        allowFailure: true, // If one fails, others still proceed
        callData: encodeFunctionData({
          abi: RWA_ORACLE_ABI,
          functionName: 'updatePrice',
          args: [s.price, s.timestamp, [s.signature]],
        }),
      }))

      const hash = await writeContractAsync({
        address: MULTICALL3_ADDRESS,
        abi: MULTICALL3_ABI,
        functionName: 'aggregate3',
        args: [calls],
      })

      toast.success('Batch update broadcasted successfully!')
      console.log('Batch Transaction Hash:', hash)

      // Invalidate the ActivityLog cache
      const networkName = chainId === 8453 ? 'base' : chainId === 42161 ? 'arbitrum' : chainId === 146 ? 'sonic' : 'mainnet'
      await invalidateActivityLog(networkName)

      setTimeout(() => {
        onClose()
      }, 2000)
    } catch (error: unknown) {
      console.error('Batch update failed:', error)
      const errorMsg =
        error instanceof Error
          ? (error as { shortMessage?: string }).shortMessage || error.message
          : 'Unknown error'
      toast.error(`Batch update failed: ${errorMsg}`)
    } finally {
      setIsSubmitting(false)
      setCurrentStep(0)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="fixed inset-0 bg-background-dark/80 backdrop-blur-sm transition-opacity"
        onClick={onClose}
      ></div>

      <div className="relative z-50 w-full max-w-2xl overflow-hidden rounded-xl border border-primary/30 bg-[#0f1623]/80 shadow-2xl backdrop-blur-xl animate-in fade-in zoom-in-95 duration-200">
        <div className="flex items-center justify-between border-b border-primary/10 bg-primary/5 px-6 py-5">
          <div>
            <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight text-white">
              <span className="material-icons-round text-primary text-xl">layers</span>
              Batch Price Update
            </h2>
            <p className="text-sm font-medium text-slate-400">
              Updating <span className="text-primary">{oracles.length}</span> oracles
            </p>
          </div>
          <button onClick={onClose} className="text-slate-500 hover:text-white transition-colors">
            <span className="material-icons-round">close</span>
          </button>
        </div>

        <div className="p-6 space-y-6">
          <div className="space-y-2 max-h-60 overflow-y-auto custom-scrollbar pr-2">
            {oracles.map((oracle) => (
              <div
                key={oracle.ticker}
                className="flex justify-between items-center bg-slate-900/50 p-3 rounded-lg border border-slate-800"
              >
                <span className="font-bold text-white">{oracle.ticker}</span>
                <div className="flex gap-4 text-sm">
                  <span className="text-slate-500">
                    On-Chain: <span className="text-white">${oracle.onChainPrice.toFixed(4)}</span>
                  </span>
                  <span className="text-slate-500">
                    New: <span className="text-primary">${oracle.offChainPrice.toFixed(4)}</span>
                  </span>
                </div>
              </div>
            ))}
          </div>

          <div className="pt-2">
            <button
              onClick={handleBatchUpdate}
              disabled={isSubmitting}
              className="w-full bg-primary hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-4 rounded-xl flex items-center justify-center gap-3 shadow-[0_0_15px_rgba(31,104,249,0.4)] uppercase tracking-widest text-sm transition-all"
            >
              {isSubmitting ? (
                <span className="material-icons-round animate-spin">refresh</span>
              ) : (
                <span className="material-icons-round">playlist_add_check</span>
              )}
              {isSubmitting
                ? currentStep === 1
                  ? 'Fetching Nonces...'
                  : currentStep === 2
                    ? 'Signing Updates...'
                    : 'Submitting Batch...'
                : 'Sign & Batch Update'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
