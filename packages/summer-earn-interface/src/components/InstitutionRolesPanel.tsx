'use client'

import { useEffect, useState } from 'react'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

// Minimal ProtocolAccessManager ABI (excluding commander)
const pamAbi = [
  {
    type: 'function',
    name: 'grantGovernorRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeGovernorRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'grantSuperKeeperRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeSuperKeeperRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'grantGuardianRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeGuardianRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'grantCuratorRole',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'fleetCommanderAddress' },
      { type: 'address', name: 'account' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeCuratorRole',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'fleetCommanderAddress' },
      { type: 'address', name: 'account' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'grantKeeperRole',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'fleetCommanderAddress' },
      { type: 'address', name: 'account' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeKeeperRole',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'fleetCommanderAddress' },
      { type: 'address', name: 'account' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'grantDecayControllerRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeDecayControllerRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'grantAdmiralsQuartersRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeAdmiralsQuartersRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'grantFoundationRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeFoundationRole',
    stateMutability: 'nonpayable',
    inputs: [{ type: 'address', name: 'account' }],
    outputs: [],
  },
] as const

type GlobalRole =
  | 'GOVERNOR_ROLE'
  | 'SUPER_KEEPER_ROLE'
  | 'GUARDIAN_ROLE'
  | 'DECAY_CONTROLLER_ROLE'
  | 'ADMIRALS_QUARTERS_ROLE'
  | 'FOUNDATION_ROLE'

type FleetRole = 'CURATOR_ROLE' | 'KEEPER_ROLE'

interface FleetOption {
  address: `0x${string}`
  label: string
}

interface InstitutionRolesPanelProps {
  protocolAccessManager: `0x${string}`
  fleets?: FleetOption[]
}

export function InstitutionRolesPanel({
  protocolAccessManager,
  fleets = [],
}: InstitutionRolesPanelProps) {
  const { isConnected } = useAccount()
  const [selectedRole, setSelectedRole] = useState<GlobalRole | FleetRole>('GOVERNOR_ROLE')
  const [userAddress, setUserAddress] = useState('')
  const [selectedFleetAddress, setSelectedFleetAddress] = useState('')
  const [action, setAction] = useState<'grant' | 'revoke'>('grant')

  const requiresTarget = selectedRole === 'CURATOR_ROLE' || selectedRole === 'KEEPER_ROLE'
  const canSubmit =
    isConnected &&
    userAddress.length === 42 &&
    (!requiresTarget || (selectedFleetAddress && selectedFleetAddress.length === 42))

  const { writeContract, data: txHash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash })

  const onSubmit = () => {
    if (!canSubmit) return
    let functionName: string
    let args: any[]
    switch (selectedRole) {
      case 'GOVERNOR_ROLE':
        functionName = action === 'grant' ? 'grantGovernorRole' : 'revokeGovernorRole'
        args = [userAddress]
        break
      case 'SUPER_KEEPER_ROLE':
        functionName = action === 'grant' ? 'grantSuperKeeperRole' : 'revokeSuperKeeperRole'
        args = [userAddress]
        break
      case 'GUARDIAN_ROLE':
        functionName = action === 'grant' ? 'grantGuardianRole' : 'revokeGuardianRole'
        args = [userAddress]
        break
      case 'DECAY_CONTROLLER_ROLE':
        functionName = action === 'grant' ? 'grantDecayControllerRole' : 'revokeDecayControllerRole'
        args = [userAddress]
        break
      case 'ADMIRALS_QUARTERS_ROLE':
        functionName =
          action === 'grant' ? 'grantAdmiralsQuartersRole' : 'revokeAdmiralsQuartersRole'
        args = [userAddress]
        break
      case 'FOUNDATION_ROLE':
        functionName = action === 'grant' ? 'grantFoundationRole' : 'revokeFoundationRole'
        args = [userAddress]
        break
      case 'CURATOR_ROLE':
        functionName = action === 'grant' ? 'grantCuratorRole' : 'revokeCuratorRole'
        args = [selectedFleetAddress, userAddress]
        break
      case 'KEEPER_ROLE':
        functionName = action === 'grant' ? 'grantKeeperRole' : 'revokeKeeperRole'
        args = [selectedFleetAddress, userAddress]
        break
      default:
        return
    }
    ;(writeContract as any)({ abi: pamAbi, address: protocolAccessManager, functionName, args })
  }

  useEffect(() => {
    if (isSuccess) {
      setUserAddress('')
      setSelectedFleetAddress('')
    }
  }, [isSuccess])

  return (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-white">Institution Roles</h3>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Role</label>
          <select
            value={selectedRole}
            onChange={(e) => setSelectedRole(e.target.value as any)}
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white"
          >
            <option value="GOVERNOR_ROLE">GOVERNOR_ROLE</option>
            <option value="SUPER_KEEPER_ROLE">SUPER_KEEPER_ROLE</option>
            <option value="GUARDIAN_ROLE">GUARDIAN_ROLE</option>
            <option value="DECAY_CONTROLLER_ROLE">DECAY_CONTROLLER_ROLE</option>
            <option value="ADMIRALS_QUARTERS_ROLE">ADMIRALS_QUARTERS_ROLE</option>
            <option value="FOUNDATION_ROLE">FOUNDATION_ROLE</option>
            <option value="CURATOR_ROLE">CURATOR_ROLE</option>
            <option value="KEEPER_ROLE">KEEPER_ROLE</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Action</label>
          <select
            value={action}
            onChange={(e) => setAction(e.target.value as 'grant' | 'revoke')}
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white"
          >
            <option value="grant">Grant</option>
            <option value="revoke">Revoke</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">User Address</label>
          <input
            type="text"
            placeholder="0x..."
            value={userAddress}
            onChange={(e) => setUserAddress(e.target.value)}
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white font-mono"
          />
        </div>
      </div>

      {requiresTarget && (
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Target Fleet</label>
          <select
            value={selectedFleetAddress}
            onChange={(e) => setSelectedFleetAddress(e.target.value)}
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white"
          >
            <option value="">Select a fleet</option>
            {fleets.map((f) => (
              <option key={f.address} value={f.address}>
                {f.label}
              </option>
            ))}
          </select>
        </div>
      )}

      <button
        onClick={onSubmit}
        disabled={!canSubmit || isPending || isConfirming}
        className={`w-full p-3 rounded-lg font-semibold transition-colors ${
          !canSubmit || isPending || isConfirming
            ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
            : action === 'grant'
              ? 'bg-green-600 hover:bg-green-700 text-white'
              : 'bg-red-600 hover:bg-red-700 text-white'
        }`}
      >
        {isPending ? 'Sending…' : isConfirming ? 'Confirming…' : `${action} ${selectedRole}`}
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
