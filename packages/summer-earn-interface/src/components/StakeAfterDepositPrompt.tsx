'use client'

import { useState } from 'react'

import type { UserFleetInfo } from '../types'
import { formatDecimalOutput } from '../utils/decimals'
import { AmountInput } from './AmountInput'

interface StakeAfterDepositPromptProps {
  userInfo: UserFleetInfo
  fleetSymbol: string
  fleetDecimals: number
  stakedBalance: bigint
  stakingRewardsManagerAddress?: string
  onApproveStaking: () => void
  onStake: (amount: string, parsedAmount: bigint) => void
  isApproveStakingLoading: boolean
  isStakeLoading: boolean
  needsStakingApproval: (amount: string) => boolean
}

export function StakeAfterDepositPrompt({
  userInfo,
  fleetSymbol,
  fleetDecimals,
  stakedBalance,
  stakingRewardsManagerAddress,
  onApproveStaking,
  onStake,
  isApproveStakingLoading,
  isStakeLoading,
  needsStakingApproval,
}: StakeAfterDepositPromptProps) {
  const [stakeAmount, setStakeAmount] = useState('')
  const [parsedStakeAmount, setParsedStakeAmount] = useState<bigint>(BigInt(0))
  const [showStakePrompt, setShowStakePrompt] = useState(true)

  // Only show if user has fleet shares and staking is available
  if (!stakingRewardsManagerAddress || userInfo.balance === BigInt(0) || !showStakePrompt) {
    return null
  }

  const handleStake = () => {
    if (parsedStakeAmount > BigInt(0)) {
      onStake(stakeAmount, parsedStakeAmount)
    }
  }

  const stakingNeedsApproval = needsStakingApproval(stakeAmount)

  return (
    <div className="bg-green-900 border border-green-600 p-6 rounded-lg relative">
      <button
        onClick={() => setShowStakePrompt(false)}
        className="absolute top-2 right-2 text-green-300 hover:text-white text-xl"
      >
        ×
      </button>

      <h3 className="text-lg font-semibold text-green-100 mb-3">
        🎉 Ready to Stake for Bonus Rewards?
      </h3>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        <div className="p-3 bg-green-800 rounded-lg">
          <p className="text-sm text-green-300">Your {fleetSymbol} Balance</p>
          <p className="font-semibold text-green-100">
            {formatDecimalOutput(userInfo.balance, fleetDecimals)} {fleetSymbol}
          </p>
        </div>
        <div className="p-3 bg-green-800 rounded-lg">
          <p className="text-sm text-green-300">Currently Staked</p>
          <p className="font-semibold text-green-100">
            {formatDecimalOutput(stakedBalance, fleetDecimals)} {fleetSymbol}
          </p>
        </div>
      </div>

      <div className="mb-4 p-3 bg-green-800 border border-green-600 rounded-lg">
        <p className="text-sm text-green-200">
          <strong>💡 Why Stake?</strong>
        </p>
        <ul className="text-xs text-green-300 mt-1 space-y-1">
          <li>• Keep earning fleet strategy yields</li>
          <li>• Get additional reward tokens on top</li>
          <li>• Unstake anytime - no lock period</li>
        </ul>
      </div>

      <div className="space-y-4">
        <AmountInput
          value={stakeAmount}
          onChange={(value, parsed) => {
            setStakeAmount(value)
            setParsedStakeAmount(parsed)
          }}
          symbol={fleetSymbol}
          decimals={fleetDecimals}
          balance={userInfo.balance}
          showMaxButton={true}
          label="Amount to Stake"
          placeholder={`Enter ${fleetSymbol} amount`}
        />

        <div className="space-y-2">
          {stakingNeedsApproval && (
            <button
              onClick={onApproveStaking}
              disabled={isApproveStakingLoading || parsedStakeAmount === BigInt(0)}
              className={`w-full p-3 rounded-lg font-semibold transition-colors ${
                isApproveStakingLoading || parsedStakeAmount === BigInt(0)
                  ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                  : 'bg-yellow-600 hover:bg-yellow-700 text-white'
              }`}
            >
              {isApproveStakingLoading ? 'Approving...' : `Approve ${fleetSymbol} for Staking`}
            </button>
          )}

          <div className="flex space-x-3">
            <button
              onClick={handleStake}
              disabled={isStakeLoading || parsedStakeAmount === BigInt(0) || stakingNeedsApproval}
              className={`flex-1 p-3 rounded-lg font-semibold transition-colors ${
                isStakeLoading || parsedStakeAmount === BigInt(0) || stakingNeedsApproval
                  ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                  : 'bg-green-600 hover:bg-green-700 text-white'
              }`}
            >
              {isStakeLoading ? 'Staking...' : `Stake ${fleetSymbol}`}
            </button>

            <button
              onClick={() => setShowStakePrompt(false)}
              className="px-4 py-3 bg-gray-600 hover:bg-gray-700 text-white rounded-lg font-medium transition-colors"
            >
              Skip
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
