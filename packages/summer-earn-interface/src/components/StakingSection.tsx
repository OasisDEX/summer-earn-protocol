'use client'

import { useState } from 'react'

import { useStakingRewards } from '../hooks/useStakingRewards'
import type { ChainId, UserFleetInfo } from '../types'
import { formatDecimalOutput } from '../utils/decimals'
import { AmountInput } from './AmountInput'
import { AddressDisplay } from './ui'

interface StakingSectionProps {
  fleetAddress: string
  fleetSymbol: string
  fleetDecimals: number
  chainId: ChainId
  userInfo: UserFleetInfo | null
}

export function StakingSection({
  fleetAddress,
  fleetSymbol,
  fleetDecimals,
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
    rewardTokensLength,
    stake,
    unstake,
    claimRewards,
    isStakeLoading,
    isUnstakeLoading,
    isClaimLoading,
    isStakeConfirmed,
    isUnstakeConfirmed,
  } = useStakingRewards({ fleetAddress, chainId })

  if (!stakingRewardsManagerAddress || !userInfo) {
    return null // Don't show staking section if no staking rewards manager or user not connected
  }

  const handleStake = () => {
    if (parsedStakeAmount > BigInt(0)) {
      stake(stakeAmount, fleetDecimals)
    }
  }

  const handleUnstake = () => {
    if (parsedUnstakeAmount > BigInt(0)) {
      unstake(unstakeAmount, fleetDecimals)
    }
  }

  const handleClaimRewards = () => {
    claimRewards()
  }

  return (
    <div className="glass rounded-2xl p-6">
      <h3 className="font-headline font-bold text-lg text-on-surface mb-6">xSUMMER Staking</h3>

      {/* Staking Info */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="p-4 bg-white/5 rounded-xl border border-white/5">
          <p className="text-[11px] text-on-surface-variant uppercase font-bold mb-1">
            Your Staked Balance
          </p>
          <p className="text-lg font-bold text-on-surface tabular-nums">
            {formatDecimalOutput(stakedBalance, fleetDecimals)} {fleetSymbol}
          </p>
        </div>

        <div className="p-4 bg-white/5 rounded-xl border border-white/5">
          <p className="text-[11px] text-on-surface-variant uppercase font-bold mb-1">
            Total Staked
          </p>
          <p className="text-lg font-bold text-on-surface tabular-nums">
            {formatDecimalOutput(totalStakedSupply, fleetDecimals)} {fleetSymbol}
          </p>
        </div>

        {rewardTokensLength > 0 && (
          <div className="p-4 bg-white/5 rounded-xl border border-white/5">
            <p className="text-[11px] text-on-surface-variant uppercase font-bold mb-1">
              Earned Rewards
            </p>
            <p className="text-lg font-bold text-secondary tabular-nums">
              {formatDecimalOutput(earnedRewards, 18)}
            </p>
            {earnedRewards > BigInt(0) && (
              <button
                onClick={handleClaimRewards}
                disabled={isClaimLoading}
                className={`mt-2 px-4 py-2 text-xs rounded-xl font-bold transition-all ${
                  isClaimLoading
                    ? 'bg-white/5 text-on-surface-variant/60 cursor-not-allowed'
                    : 'bg-primary hover:bg-primary-dim border border-primary/50 text-on-primary'
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
          <h4 className="text-lg font-medium text-on-surface">Stake Fleet Shares</h4>

          <AmountInput
            value={stakeAmount}
            onChange={(value, parsed) => {
              setStakeAmount(value)
              setParsedStakeAmount(parsed)
            }}
            symbol={fleetSymbol}
            decimals={fleetDecimals}
            balance={userInfo.balance} // Use fleet token balance for staking
            showMaxButton={true}
            label="Amount to Stake"
            placeholder={`Enter ${fleetSymbol} amount`}
          />

          <button
            onClick={handleStake}
            disabled={isStakeLoading || parsedStakeAmount === BigInt(0)}
            className={`w-full py-3 rounded-xl font-bold transition-all ${
              isStakeLoading || parsedStakeAmount === BigInt(0)
                ? 'bg-white/5 text-on-surface-variant/60 cursor-not-allowed'
                : 'bg-primary hover:bg-primary-dim border border-primary/50 text-on-primary'
            }`}
          >
            {isStakeLoading ? 'Staking...' : `Stake ${fleetSymbol}`}
          </button>

          {isStakeConfirmed && (
            <div className="p-3 bg-success/10 border border-success/20 rounded-xl">
              <p className="text-success text-sm">
                Successfully staked {stakeAmount} {fleetSymbol}!
              </p>
            </div>
          )}
        </div>

        {/* Unstake Section */}
        <div className="space-y-4">
          <h4 className="text-lg font-medium text-on-surface">Unstake Fleet Shares</h4>

          <AmountInput
            value={unstakeAmount}
            onChange={(value, parsed) => {
              setUnstakeAmount(value)
              setParsedUnstakeAmount(parsed)
            }}
            symbol={fleetSymbol}
            decimals={fleetDecimals}
            balance={stakedBalance} // Use staked balance for unstaking
            showMaxButton={true}
            label="Amount to Unstake"
            placeholder={`Enter ${fleetSymbol} amount`}
          />

          <button
            onClick={handleUnstake}
            disabled={isUnstakeLoading || parsedUnstakeAmount === BigInt(0)}
            className={`w-full py-3 rounded-xl font-bold transition-all ${
              isUnstakeLoading || parsedUnstakeAmount === BigInt(0)
                ? 'bg-white/5 text-on-surface-variant/60 cursor-not-allowed'
                : 'bg-primary/20 border border-primary/30 text-primary hover:bg-primary/30'
            }`}
          >
            {isUnstakeLoading ? 'Unstaking...' : `Unstake ${fleetSymbol}`}
          </button>

          {isUnstakeConfirmed && (
            <div className="p-3 bg-success/10 border border-success/20 rounded-xl">
              <p className="text-success text-sm">
                Successfully unstaked {unstakeAmount} {fleetSymbol}!
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Staking Info */}
      <div className="mt-6 p-4 bg-white/5 rounded-xl border border-white/5">
        <h5 className="text-xs font-bold text-on-surface-variant uppercase mb-2">About Staking</h5>
        <div className="text-sm text-on-surface-variant space-y-1">
          <p>• Stake your {fleetSymbol} fleet shares to earn additional rewards</p>
          <p>• Staked shares continue earning fleet returns plus bonus rewards</p>
          <p>• You can unstake at any time, but rewards accrue over time</p>
          <p>• Claim your rewards regularly to compound your earnings</p>
        </div>
      </div>

      {/* Contract Info */}
      <div className="mt-4 p-3 bg-white/5 rounded-xl border border-white/5">
        <p className="text-xs text-on-surface-variant">
          <strong>Staking Contract:</strong>{' '}
          <AddressDisplay value={stakingRewardsManagerAddress} chars={6} className="text-primary" />
        </p>
      </div>
    </div>
  )
}
