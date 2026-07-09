'use client'

import { useState } from 'react'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

// Minimal ABI: IWhitelist.setWhitelisted(address,bool)
const whitelistAbi = [
  {
    type: 'function',
    name: 'setWhitelisted',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'allowed', type: 'bool' },
    ],
    outputs: [],
  },
] as const

interface AdmiralsWhitelistToggleProps {
  admiralsQuarters: `0x${string}`
}

export function AdmiralsWhitelistToggle({ admiralsQuarters }: AdmiralsWhitelistToggleProps) {
  const [enabled, setEnabled] = useState<boolean>(false)
  const { address: walletAddress } = useAccount()
  const { writeContract, data: txHash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  const handleToggle = () => {
    if (isPending || isConfirming) return
    if (!walletAddress) return

    writeContract({
      abi: whitelistAbi,
      address: admiralsQuarters,
      functionName: 'setWhitelisted',
      args: ['0x0000000000000000000000000000000000000000', !enabled],
      account: walletAddress,
    } as unknown as Parameters<typeof writeContract>[0])
    setEnabled((prev) => !prev)
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-sm text-on-surface-variant">Admirals Quarters Whitelist</p>
        <button
          onClick={handleToggle}
          disabled={isPending || isConfirming}
          className={`px-3 py-1 rounded-md text-sm font-semibold transition-colors ${
            isPending || isConfirming
              ? 'bg-white/5 border border-white/10 text-on-surface-variant/50 cursor-not-allowed'
              : enabled
                ? 'bg-error/15 border border-error/30 text-error hover:bg-error/25'
                : 'bg-secondary/15 border border-secondary/30 text-secondary hover:bg-secondary/25'
          }`}
        >
          {isPending ? 'Sending…' : isConfirming ? 'Confirming…' : enabled ? 'Disable' : 'Enable'}
        </button>
      </div>
      {error && (
        <div className="p-3 bg-error/15 border border-error/30 rounded-lg text-error text-sm">
          {error.message}
        </div>
      )}
      {isSuccess && (
        <div className="p-3 bg-success/15 border border-success/30 rounded-lg text-success text-sm">
          Success! Transaction confirmed.
        </div>
      )}
    </div>
  )
}
