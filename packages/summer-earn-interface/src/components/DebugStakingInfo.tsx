'use client'

import { useStakingRewards } from '../hooks/useStakingRewards'
import type { ChainId, UserFleetInfo } from '../types'

interface DebugStakingInfoProps {
  fleetAddress: string
  chainId: ChainId
  userInfo: UserFleetInfo | null
}

export function DebugStakingInfo({ fleetAddress, chainId, userInfo }: DebugStakingInfoProps) {
  const { stakingRewardsManagerAddress, stakedBalance, fleetConfig } = useStakingRewards({
    fleetAddress,
    chainId,
  })

  // Only show in development
  if (process.env.NODE_ENV !== 'development') return null

  return (
    <div className="bg-yellow-900 border border-yellow-600 p-4 rounded-lg mb-4">
      <h4 className="text-yellow-200 font-semibold mb-2">🔧 Debug Info:</h4>
      <div className="text-xs text-yellow-300 space-y-1">
        <p>
          <strong>User Connected:</strong> {userInfo ? '✅ Yes' : '❌ No'}
        </p>
        <p>
          <strong>Fleet Balance:</strong> {userInfo?.balance?.toString() || 'N/A'}
        </p>
        <p>
          <strong>Balance above 0:</strong>{' '}
          {userInfo && userInfo.balance > BigInt(0) ? '✅ Yes' : '❌ No'}
        </p>
        <p>
          <strong>Staking Manager:</strong> {stakingRewardsManagerAddress || '❌ Not found'}
        </p>
        <p>
          <strong>Current Staked:</strong> {stakedBalance?.toString() || '0'}
        </p>
        <p>
          <strong>Fleet Config:</strong> {fleetConfig?.toString() || 'N/A'}
        </p>
        <div className="mt-2 p-2 bg-yellow-800 rounded">
          <p className="text-yellow-100 text-xs">
            <strong>StakeAfterDepositPrompt shows when:</strong>
            <br />
            • User connected ✓<br />
            • User has fleet balance &gt; 0 ✓<br />• Staking manager exists ✓
          </p>
        </div>
      </div>
    </div>
  )
}
