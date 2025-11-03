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
        <p className="text-sm text-gray-300">Admirals Quarters Whitelist</p>
        <button
          onClick={handleToggle}
          disabled={isPending || isConfirming}
          className={`px-3 py-1 rounded-md text-sm font-semibold ${
            isPending || isConfirming
              ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
              : enabled
                ? 'bg-red-600 hover:bg-red-700 text-white'
                : 'bg-green-600 hover:bg-green-700 text-white'
          }`}
        >
          {isPending ? 'Sending…' : isConfirming ? 'Confirming…' : enabled ? 'Disable' : 'Enable'}
        </button>
      </div>
      {error && (
        <div className="p-3 bg-red-900 border border-red-600 rounded-lg text-red-200 text-sm">
          {error.message}
        </div>
      )}
      {isSuccess && (
        <div className="p-3 bg-green-900 border border-green-600 rounded-lg text-green-200 text-sm">
          Success! Transaction confirmed.
        </div>
      )}
    </div>
  )
}
