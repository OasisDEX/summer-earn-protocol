'use client'

import { useEffect, useState } from 'react'
import { useAccount, useReadContract, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { protocolAccessManagerAbi } from '../abis/ProtocolAccessManager'
import type { Environment } from '../config/environments'
import { useRoleConstants } from '../hooks/useRoleConstants'
import type { ArkRole, ChainId, FleetRole, GlobalRole } from '../types'

interface RoleManagerProps {
  chainId: ChainId
  contractAddress: string
  selectedRole: GlobalRole | FleetRole | ArkRole
  targetContract?: string
  environment: Environment
}

export function RoleManager({
  chainId,
  contractAddress,
  selectedRole,
  targetContract,
  environment,
}: RoleManagerProps) {
  const { address: connectedAddress, isConnected } = useAccount()
  const [userAddress, setUserAddress] = useState('')
  const [action, setAction] = useState<'grant' | 'revoke'>('grant')

  const { writeContract, isPending: isWriting, error: writeError, data: txHash } = useWriteContract()
  const { getRoleHash } = useRoleConstants({ contractAddress, chainId })

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash: txHash,
  })

  // Get the role hash for checking current status
  const getRoleHashForCheck = (): `0x${string}` | undefined => {
    if (!userAddress || userAddress.length !== 42) return undefined

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
      roleHashForCheck && userAddress.length === 42
        ? [roleHashForCheck, userAddress as `0x${string}`]
        : undefined,
    query: {
      enabled: !!roleHashForCheck && !!userAddress && userAddress.length === 42,
    },
  })

  const requiresTargetContract = ['CURATOR_ROLE', 'KEEPER_ROLE', 'COMMANDER_ROLE'].includes(
    selectedRole,
  )

  const canSubmit =
    isConnected &&
    userAddress.length === 42 &&
    (!requiresTargetContract || (targetContract && targetContract.length === 42))

  const handleSubmit = async () => {
    if (!canSubmit) return

    try {
      let functionName: string
      let args: any[]

      // Determine the correct function and arguments based on role and action
      if (selectedRole === 'GOVERNOR_ROLE') {
        functionName = action === 'grant' ? 'grantGovernorRole' : 'revokeGovernorRole'
        args = [userAddress]
      } else if (selectedRole === 'SUPER_KEEPER_ROLE') {
        functionName = action === 'grant' ? 'grantSuperKeeperRole' : 'revokeSuperKeeperRole'
        args = [userAddress]
      } else if (selectedRole === 'GUARDIAN_ROLE') {
        functionName = action === 'grant' ? 'grantGuardianRole' : 'revokeGuardianRole'
        args = [userAddress]
      } else if (selectedRole === 'DECAY_CONTROLLER_ROLE') {
        functionName = action === 'grant' ? 'grantDecayControllerRole' : 'revokeDecayControllerRole'
        args = [userAddress]
      } else if (selectedRole === 'ADMIRALS_QUARTERS_ROLE') {
        functionName =
          action === 'grant' ? 'grantAdmiralsQuartersRole' : 'revokeAdmiralsQuartersRole'
        args = [userAddress]
      } else if (selectedRole === 'FOUNDATION_ROLE') {
        functionName = action === 'grant' ? 'grantFoundationRole' : 'revokeFoundationRole'
        args = [userAddress]
      } else if (selectedRole === 'CURATOR_ROLE') {
        functionName = action === 'grant' ? 'grantCuratorRole' : 'revokeCuratorRole'
        args = [targetContract, userAddress]
      } else if (selectedRole === 'KEEPER_ROLE') {
        functionName = action === 'grant' ? 'grantKeeperRole' : 'revokeKeeperRole'
        args = [targetContract, userAddress]
      } else if (selectedRole === 'COMMANDER_ROLE') {
        functionName = action === 'grant' ? 'grantCommanderRole' : 'revokeCommanderRole'
        args = [targetContract, userAddress]
      } else {
        throw new Error(`Unsupported role: ${selectedRole}`)
      }

      (writeContract as any)({
        abi: protocolAccessManagerAbi,
        address: contractAddress as `0x${string}`,
        functionName,
        args,
      })
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
      <h3 className="text-lg font-semibold text-white">
        Manage Role: {selectedRole.replace('_', ' ')}
      </h3>

      {!isConnected && (
        <div className="p-4 bg-yellow-900 border border-yellow-600 rounded-lg">
          <p className="text-yellow-200">Please connect your wallet to manage roles.</p>
        </div>
      )}

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">Action</label>
          <select
            value={action}
            onChange={(e) => setAction(e.target.value as 'grant' | 'revoke')}
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="grant">Grant Role</option>
            <option value="revoke">Revoke Role</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">User Address</label>
          <input
            type="text"
            placeholder="0x..."
            value={userAddress}
            onChange={(e) => setUserAddress(e.target.value)}
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent font-mono"
          />
        </div>

        {requiresTargetContract && targetContract && (
          <div className="p-4 bg-gray-800 rounded-lg">
            <p className="text-sm text-gray-300">
              <strong>Target Contract:</strong>{' '}
              <span className="font-mono text-blue-300">{targetContract}</span>
            </p>
          </div>
        )}

        {userAddress.length === 42 && hasRole !== undefined && (
          <div className="p-4 bg-gray-800 rounded-lg">
            <p className="text-sm text-gray-300">
              <strong>Current Status:</strong>{' '}
              <span className={`font-semibold ${hasRole ? 'text-green-400' : 'text-red-400'}`}>
                {hasRole ? 'Has Role' : 'Does Not Have Role'}
              </span>
            </p>
          </div>
        )}

        <button
          onClick={handleSubmit}
          disabled={!canSubmit || isWriting || isConfirming}
          className={`w-full p-3 rounded-lg font-semibold transition-colors ${
            canSubmit && !isWriting && !isConfirming
              ? action === 'grant'
                ? 'bg-green-600 hover:bg-green-700 text-white'
                : 'bg-red-600 hover:bg-red-700 text-white'
              : 'bg-gray-600 text-gray-400 cursor-not-allowed'
          }`}
        >
          {isWriting
            ? 'Sending Transaction...'
            : isConfirming
              ? 'Confirming...'
              : `${action === 'grant' ? 'Grant' : 'Revoke'} ${selectedRole.replace('_', ' ')}`}
        </button>

        {writeError && (
          <div className="p-4 bg-red-900 border border-red-600 rounded-lg">
            <p className="text-red-200 text-sm">
              <strong>Error:</strong> {writeError.message}
            </p>
          </div>
        )}

        {isConfirmed && (
          <div className="p-4 bg-green-900 border border-green-600 rounded-lg">
            <p className="text-green-200 text-sm">
              <strong>Success!</strong> Transaction confirmed.
            </p>
          </div>
        )}

        {txHash && (
          <div className="p-4 bg-gray-800 rounded-lg">
            <p className="text-sm text-gray-300">
              <strong>Transaction Hash:</strong>{' '}
              <span className="font-mono text-blue-300 break-all">{txHash}</span>
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
