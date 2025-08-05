'use client'

import { useState } from 'react'
import { AmountInput } from './AmountInput'
import { useStakingRewards } from '../hooks/useStakingRewards'
import { formatDecimalOutput } from '../utils/decimals'
import type { ChainId, UserFleetInfo } from '../types'

interface StakingSectionProps {
  fleetAddress: string
  fleetSymbol: string
  chainId: ChainId
  userInfo: UserFleetInfo | null
}

export function StakingSection({
  fleetAddress,
  fleetSymbol,
  chainId,
  userInfo,
}: StakingSectionProps) {
  const [stakeAmount, setStakeAmount] = useState('')
  const [parsedStakeAmount, setParsedStakeAmount] = useState<bigint>(BigInt(0))
  const [unstakeAmount, setUnstakeAmount] = useState('')
  const [parsedUnstakeAmount, setParsedUnstakeAmount] = useState<bigint>(BigInt(0))

  const {
    stakingRewardsManagerAddress,
    stakedBalance,
    totalStakedSupply,
    earnedRewards,
    rewardTokens,
    rewardTokensLength,
    stake,
    unstake,
    claimRewards,
    isStakeLoading,
    isUnstakeLoading,
    isClaimLoading,
    isStakeConfirmed,
    isUnstakeConfirmed,
    isClaimConfirmed,
  } = useStakingRewards({ fleetAddress, chainId })

  if (!stakingRewardsManagerAddress || !userInfo) {
    return null // Don't show staking section if no staking rewards manager or user not connected
  }

  const handleStake = () => {
    if (parsedStakeAmount > BigInt(0)) {
      stake(stakeAmount)
    }
  }

  const handleUnstake = () => {
    if (parsedUnstakeAmount > BigInt(0)) {
      unstake(unstakeAmount)
    }
  }

  const handleClaimRewards = () => {
    claimRewards()
  }

  return (
    <div className="bg-gray-900 p-6 rounded-lg">
      <h3 className="text-xl font-semibold text-white mb-6">Staking Rewards</h3>
      
      {/* Staking Info */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="p-4 bg-gray-800 rounded-lg">
          <p className="text-sm text-gray-400">Your Staked Balance</p>
          <p className="text-lg font-semibold text-white">
            {formatDecimalOutput(stakedBalance, 18)} {fleetSymbol}
          </p>
        </div>
        
        <div className="p-4 bg-gray-800 rounded-lg">
          <p className="text-sm text-gray-400">Total Staked</p>
          <p className="text-lg font-semibold text-white">
            {formatDecimalOutput(totalStakedSupply, 18)} {fleetSymbol}
          </p>
        </div>
        
        {rewardTokensLength > 0 && (
          <div className="p-4 bg-gray-800 rounded-lg">
            <p className="text-sm text-gray-400">Earned Rewards</p>
            <p className="text-lg font-semibold text-green-400">
              {formatDecimalOutput(earnedRewards, 18)}
            </p>
            {earnedRewards > BigInt(0) && (
              <button
                onClick={handleClaimRewards}
                disabled={isClaimLoading}
                className={`mt-2 px-3 py-1 text-xs rounded-md font-medium transition-colors ${
                  isClaimLoading
                    ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                    : 'bg-green-600 hover:bg-green-700 text-white'
                }`}
              >
                {isClaimLoading ? 'Claiming...' : 'Claim'}
              </button>
            )}
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Stake Section */}
        <div className="space-y-4">
          <h4 className="text-lg font-medium text-white">Stake Fleet Shares</h4>
          
          <AmountInput
            value={stakeAmount}
            onChange={(value, parsed) => {
              setStakeAmount(value)
              setParsedStakeAmount(parsed)
            }}
            symbol={fleetSymbol}
            decimals={18}
            balance={userInfo.balance} // Use fleet token balance for staking
            showMaxButton={true}
            label="Amount to Stake"
            placeholder={`Enter ${fleetSymbol} amount`}
          />
          
          <button
            onClick={handleStake}
            disabled={isStakeLoading || parsedStakeAmount === BigInt(0)}
            className={`w-full p-3 rounded-lg font-semibold transition-colors ${
              isStakeLoading || parsedStakeAmount === BigInt(0)
                ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                : 'bg-blue-600 hover:bg-blue-700 text-white'
            }`}
          >
            {isStakeLoading ? 'Staking...' : `Stake ${fleetSymbol}`}
          </button>
          
          {isStakeConfirmed && (
            <div className="p-3 bg-green-900 border border-green-600 rounded-lg">
              <p className="text-green-200 text-sm">
                Successfully staked {stakeAmount} {fleetSymbol}!
              </p>
            </div>
          )}
        </div>

        {/* Unstake Section */}
        <div className="space-y-4">
          <h4 className="text-lg font-medium text-white">Unstake Fleet Shares</h4>
          
          <AmountInput
            value={unstakeAmount}
            onChange={(value, parsed) => {
              setUnstakeAmount(value)
              setParsedUnstakeAmount(parsed)
            }}
            symbol={fleetSymbol}
            decimals={18}
            balance={stakedBalance} // Use staked balance for unstaking
            showMaxButton={true}
            label="Amount to Unstake"
            placeholder={`Enter ${fleetSymbol} amount`}
          />
          
          <button
            onClick={handleUnstake}
            disabled={isUnstakeLoading || parsedUnstakeAmount === BigInt(0)}
            className={`w-full p-3 rounded-lg font-semibold transition-colors ${
              isUnstakeLoading || parsedUnstakeAmount === BigInt(0)
                ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                : 'bg-orange-600 hover:bg-orange-700 text-white'
            }`}
          >
            {isUnstakeLoading ? 'Unstaking...' : `Unstake ${fleetSymbol}`}
          </button>
          
          {isUnstakeConfirmed && (
            <div className="p-3 bg-green-900 border border-green-600 rounded-lg">
              <p className="text-green-200 text-sm">
                Successfully unstaked {unstakeAmount} {fleetSymbol}!
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Staking Info */}
      <div className="mt-6 p-4 bg-gray-800 rounded-lg">
        <h5 className="text-sm font-medium text-gray-300 mb-2">About Staking</h5>
        <div className="text-sm text-gray-400 space-y-1">
          <p>• Stake your {fleetSymbol} fleet shares to earn additional rewards</p>
          <p>• Staked shares continue earning fleet returns plus bonus rewards</p>
          <p>• You can unstake at any time, but rewards accrue over time</p>
          <p>• Claim your rewards regularly to compound your earnings</p>
        </div>
      </div>

      {/* Contract Info */}
      <div className="mt-4 p-3 bg-gray-800 rounded-lg">
        <p className="text-xs text-gray-400">
          <strong>Staking Contract:</strong>{' '}
          <span className="font-mono text-blue-300">{stakingRewardsManagerAddress}</span>
        </p>
      </div>
    </div>
  )
}