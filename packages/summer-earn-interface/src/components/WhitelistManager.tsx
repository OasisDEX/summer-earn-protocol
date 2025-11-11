'use client'

import { useState } from 'react'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

// Minimal ABI shape for whitelist management on FleetCommanderWhitelist (setWhitelisted / setWhitelistedBatch)
const fleetCommanderWhitelistAbi = [
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
  {
    type: 'function',
    name: 'isWhitelisted',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'bool' }],
  },
] as const

interface WhitelistManagerProps {
  fleetAddress: `0x${string}`
}

export function WhitelistManager({ fleetAddress }: WhitelistManagerProps) {
  const { isConnected, chain, address: account } = useAccount()
  const [address, setAddress] = useState('')
  const [allowed, setAllowed] = useState(true)
  const { writeContract, data: txHash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  const normalizedAddress =
    address.length === 42 && address.startsWith('0x') ? (address as `0x${string}`) : null
  const canSubmit = isConnected && normalizedAddress !== null

  const handleSubmit = () => {
    if (!normalizedAddress) return
    writeContract({
      abi: fleetCommanderWhitelistAbi,
      address: fleetAddress,
      functionName: 'setWhitelisted',
      args: [normalizedAddress, allowed],
      chain: chain,
      account: account,
    })
  }

  return (
    <div className="space-y-4">
      <h4 className="text-md font-semibold text-white">Whitelist Users</h4>
      <div>
        <label className="block text-sm font-medium text-gray-300 mb-2">User Address</label>
        <input
          type="text"
          placeholder="0x..."
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent font-mono"
        />
      </div>

      <div className="flex items-center gap-3">
        <input
          id="wl-allowed"
          type="checkbox"
          checked={allowed}
          onChange={(e) => setAllowed(e.target.checked)}
          className="h-4 w-4"
        />
        <label htmlFor="wl-allowed" className="text-sm text-gray-300">
          Allow (unchecked will revoke)
        </label>
      </div>

      <button
        onClick={handleSubmit}
        disabled={!canSubmit || isPending || isConfirming}
        className={`w-full p-3 rounded-lg font-semibold transition-colors ${
          canSubmit && !isPending && !isConfirming
            ? 'bg-blue-600 hover:bg-blue-700 text-white'
            : 'bg-gray-600 text-gray-400 cursor-not-allowed'
        }`}
      >
        {isPending ? 'Sending...' : isConfirming ? 'Confirming...' : 'Update Whitelist'}
      </button>

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
