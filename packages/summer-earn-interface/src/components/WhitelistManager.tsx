'use client'

import { useState } from 'react'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { checkboxBase, inputBase, labelBase } from './ui'

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
      <h4 className="text-base font-headline font-semibold text-on-surface">Whitelist Users</h4>
      <div>
        <label className={labelBase}>User Address</label>
        <input
          type="text"
          placeholder="0x…"
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          className={`${inputBase} font-mono`}
        />
      </div>

      <div className="flex items-center gap-3">
        <input
          id="wl-allowed"
          type="checkbox"
          checked={allowed}
          onChange={(e) => setAllowed(e.target.checked)}
          className={checkboxBase}
        />
        <label htmlFor="wl-allowed" className="text-sm text-on-surface-variant">
          Allow (unchecked will revoke)
        </label>
      </div>

      <button
        onClick={handleSubmit}
        disabled={!canSubmit || isPending || isConfirming}
        className={`w-full p-3 rounded-lg font-semibold transition-colors ${
          canSubmit && !isPending && !isConfirming
            ? 'bg-primary text-on-primary hover:bg-primary-dim'
            : 'bg-white/5 border border-white/10 text-on-surface-variant/50 cursor-not-allowed'
        }`}
      >
        {isPending ? 'Sending…' : isConfirming ? 'Confirming…' : 'Update Whitelist'}
      </button>

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
