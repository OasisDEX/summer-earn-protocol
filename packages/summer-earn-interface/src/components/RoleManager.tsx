'use client'

import { useEffect, useState } from 'react'
import { useAccount, useReadContract, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { useRoleConstants } from '../hooks/useRoleConstants'
import type { ArkRole, FleetRole, GlobalRole } from '../types'
import { AddressDisplay, Badge, inputBase, labelBase, selectBase } from './ui'
// Inline minimal ABI for ProtocolAccessManager to avoid external import coupling
const protocolAccessManagerAbi = [
  {
    type: 'function',
    name: 'hasRole',
    stateMutability: 'view',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    type: 'function',
    name: 'GOVERNOR_ROLE',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
  },
  {
    type: 'function',
    name: 'SUPER_KEEPER_ROLE',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
  },
  {
    type: 'function',
    name: 'GUARDIAN_ROLE',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
  },
  {
    type: 'function',
    name: 'DECAY_CONTROLLER_ROLE',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
  },
  {
    type: 'function',
    name: 'ADMIRALS_QUARTERS_ROLE',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
  },
  {
    type: 'function',
    name: 'FOUNDATION_ROLE',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bytes32' }],
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
    name: 'grantCommanderRole',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'arkAddress' },
      { type: 'address', name: 'account' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeCommanderRole',
    stateMutability: 'nonpayable',
    inputs: [
      { type: 'address', name: 'arkAddress' },
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
] as const

interface RoleManagerProps {
  contractAddress: string
  selectedRole: GlobalRole | FleetRole | ArkRole
  targetContract?: string
}

export function RoleManager({ contractAddress, selectedRole, targetContract }: RoleManagerProps) {
  const { address: connectedAccount, isConnected, chain } = useAccount()
  const [userAddress, setUserAddress] = useState('')
  const [action, setAction] = useState<'grant' | 'revoke'>('grant')

  const {
    writeContract,
    isPending: isWriting,
    error: writeError,
    data: txHash,
  } = useWriteContract()
  const { getRoleHash } = useRoleConstants({ contractAddress })

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash,
  })

  const normalizedUserAddress =
    userAddress.length === 42 && userAddress.startsWith('0x')
      ? (userAddress as `0x${string}`)
      : null

  const normalizedTargetAddress =
    targetContract && targetContract.length === 42 && targetContract.startsWith('0x')
      ? (targetContract as `0x${string}`)
      : null

  // Get the role hash for checking current status
  const getRoleHashForCheck = (): `0x${string}` | undefined => {
    if (!normalizedUserAddress) return undefined

    // For global roles, use the role constant
    if (
      [
        'GOVERNOR_ROLE',
        'SUPER_KEEPER_ROLE',
        'GUARDIAN_ROLE',
        'DECAY_CONTROLLER_ROLE',
        'ADMIRALS_QUARTERS_ROLE',
        'FOUNDATION_ROLE',
      ].includes(selectedRole)
    ) {
      return getRoleHash(selectedRole as GlobalRole)
    }

    // For contract-specific roles, we would need to generate the role hash
    // This requires calling generateRole function with the role enum and target contract
    return undefined
  }

  // Read current role status for the user address
  const roleHashForCheck = getRoleHashForCheck()
  const { data: hasRole, refetch: refetchRole } = useReadContract({
    abi: protocolAccessManagerAbi,
    address: contractAddress as `0x${string}`,
    functionName: 'hasRole',
    args:
      roleHashForCheck && normalizedUserAddress
        ? [roleHashForCheck, normalizedUserAddress]
        : undefined,
    query: {
      enabled: Boolean(roleHashForCheck && normalizedUserAddress),
    },
  })

  const requiresTargetContract = ['CURATOR_ROLE', 'KEEPER_ROLE', 'COMMANDER_ROLE'].includes(
    selectedRole,
  )

  const canSubmit =
    isConnected &&
    normalizedUserAddress !== null &&
    (!requiresTargetContract || normalizedTargetAddress !== null)

  const handleSubmit = async () => {
    if (!canSubmit || !normalizedUserAddress || !connectedAccount || !chain) return

    try {
      switch (selectedRole) {
        case 'GOVERNOR_ROLE':
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName: action === 'grant' ? 'grantGovernorRole' : 'revokeGovernorRole',
            args: [normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        case 'SUPER_KEEPER_ROLE':
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName: action === 'grant' ? 'grantSuperKeeperRole' : 'revokeSuperKeeperRole',
            args: [normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        case 'GUARDIAN_ROLE':
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName: action === 'grant' ? 'grantGuardianRole' : 'revokeGuardianRole',
            args: [normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        case 'DECAY_CONTROLLER_ROLE':
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName:
              action === 'grant' ? 'grantDecayControllerRole' : 'revokeDecayControllerRole',
            args: [normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        case 'ADMIRALS_QUARTERS_ROLE':
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName:
              action === 'grant' ? 'grantAdmiralsQuartersRole' : 'revokeAdmiralsQuartersRole',
            args: [normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        case 'FOUNDATION_ROLE':
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName: action === 'grant' ? 'grantFoundationRole' : 'revokeFoundationRole',
            args: [normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        case 'CURATOR_ROLE':
          if (!normalizedTargetAddress) return
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName: action === 'grant' ? 'grantCuratorRole' : 'revokeCuratorRole',
            args: [normalizedTargetAddress, normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        case 'KEEPER_ROLE':
          if (!normalizedTargetAddress) return
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName: action === 'grant' ? 'grantKeeperRole' : 'revokeKeeperRole',
            args: [normalizedTargetAddress, normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        case 'COMMANDER_ROLE':
          if (!normalizedTargetAddress) return
          await writeContract({
            abi: protocolAccessManagerAbi,
            address: contractAddress as `0x${string}`,
            functionName: action === 'grant' ? 'grantCommanderRole' : 'revokeCommanderRole',
            args: [normalizedTargetAddress, normalizedUserAddress] as const,
            chain: chain,
            account: connectedAccount,
          })
          break
        default:
          throw new Error(`Unsupported role: ${selectedRole}`)
      }
    } catch (error) {
      console.error('Transaction failed:', error)
    }
  }

  // Clear transaction state when role or target changes
  // Note: txHash will be automatically cleared by wagmi when a new transaction is initiated

  // Refetch role status after successful transaction
  useEffect(() => {
    if (isConfirmed) {
      refetchRole()
    }
  }, [isConfirmed, refetchRole])

  return (
    <div className="space-y-6">
      <h3 className="text-lg font-headline font-semibold text-on-surface">
        Manage Role: {selectedRole.replace('_', ' ')}
      </h3>

      {!isConnected && (
        <div className="p-4 bg-warning/15 border border-warning/30 rounded-lg">
          <p className="text-warning">Please connect your wallet to manage roles.</p>
        </div>
      )}

      <div className="space-y-4">
        <div>
          <label className={labelBase}>Action</label>
          <select
            value={action}
            onChange={(e) => setAction(e.target.value as 'grant' | 'revoke')}
            className={`${selectBase} w-full`}
          >
            <option value="grant">Grant Role</option>
            <option value="revoke">Revoke Role</option>
          </select>
        </div>

        <div>
          <label className={labelBase}>User Address</label>
          <input
            type="text"
            placeholder="0x…"
            value={userAddress}
            onChange={(e) => setUserAddress(e.target.value)}
            className={`${inputBase} font-mono`}
          />
        </div>

        {requiresTargetContract && targetContract && (
          <div className="p-4 bg-surface-container-high border border-white/10 rounded-lg">
            <p className="text-sm text-on-surface-variant">
              <strong>Target Contract:</strong>{' '}
              <AddressDisplay value={targetContract} full className="text-info" />
            </p>
          </div>
        )}

        {normalizedUserAddress && hasRole !== undefined && (
          <div className="p-4 bg-surface-container-high border border-white/10 rounded-lg">
            <p className="text-sm text-on-surface-variant flex items-center gap-2">
              <strong>Current Status:</strong>{' '}
              <Badge tone={hasRole ? 'success' : 'danger'} size="sm">
                {hasRole ? 'Has Role' : 'Does Not Have Role'}
              </Badge>
            </p>
          </div>
        )}

        <button
          onClick={handleSubmit}
          disabled={!canSubmit || isWriting || isConfirming}
          className={`w-full p-3 rounded-lg font-semibold transition-colors ${
            canSubmit && !isWriting && !isConfirming
              ? action === 'grant'
                ? 'bg-secondary/15 border border-secondary/30 text-secondary hover:bg-secondary/25'
                : 'bg-error/15 border border-error/30 text-error hover:bg-error/25'
              : 'bg-white/5 border border-white/10 text-on-surface-variant/50 cursor-not-allowed'
          }`}
        >
          {isWriting
            ? 'Sending Transaction…'
            : isConfirming
              ? 'Confirming…'
              : `${action === 'grant' ? 'Grant' : 'Revoke'} ${selectedRole.replace('_', ' ')}`}
        </button>

        {writeError && (
          <div className="p-4 bg-error/15 border border-error/30 rounded-lg">
            <p className="text-error text-sm">
              <strong>Error:</strong> {writeError.message}
            </p>
          </div>
        )}

        {isConfirmed && (
          <div className="p-4 bg-success/15 border border-success/30 rounded-lg">
            <p className="text-success text-sm">
              <strong>Success!</strong> Transaction confirmed.
            </p>
          </div>
        )}

        {txHash && (
          <div className="p-4 bg-surface-container-high border border-white/10 rounded-lg">
            <p className="text-sm text-on-surface-variant">
              <strong>Transaction Hash:</strong>{' '}
              <AddressDisplay value={txHash} full className="text-info" />
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
