'use client'

import Link from 'next/link'
import { useState } from 'react'
import { formatUnits } from 'viem'
import { useFleetActions } from '../hooks/useFleetActions'
import { useStakingRewards } from '../hooks/useStakingRewards'
import { ChainId, FleetCommanderInfo, UserFleetInfo } from '../types'
import { formatDecimalOutput } from '../utils/decimals'

interface FleetCardProps {
  fleetInfo: FleetCommanderInfo
  userInfo: UserFleetInfo | null
  assetDecimals: number
  assetSymbol: string
  chainId: string
}

export function FleetCard({
  fleetInfo,
  userInfo,
  assetDecimals,
  assetSymbol,
  chainId,
}: FleetCardProps) {
  const [amount, setAmount] = useState<string>('')

  const { approve, deposit, withdraw, isApproveLoading, isDepositLoading, isWithdrawLoading } =
    useFleetActions({
      fleetAddress: fleetInfo.address as `0x${string}`,
      assetAddress: fleetInfo.asset as `0x${string}`,
      assetDecimals,
      chainId: chainId as ChainId,
    })

  const { stakedBalance, stakingRewardsManagerAddress } = useStakingRewards({
    fleetAddress: fleetInfo.address,
    chainId: chainId as ChainId,
  })

  const needsApproval =
    userInfo && userInfo.allowance < BigInt(amount || '0') && BigInt(amount || '0') > BigInt(0)

  const handleDeposit = () => {
    if (needsApproval) {
      approve(amount)
    } else {
      deposit(amount)
    }
  }

  const handleWithdraw = () => {
    withdraw(amount)
  }

  return (
    <div className="bg-charcoal-800/70 rounded-xl p-6 mb-4 border border-white/10 shadow-card backdrop-blur">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-xl font-semibold text-white">{fleetInfo.name}</h2>
        <span className="text-xs bg-violet-500/20 text-violet-400 py-0.5 px-1.5 rounded-full border border-violet-500/30">
          {fleetInfo.symbol}
        </span>
      </div>

      <div className="space-y-4 mb-4">
        <div className="p-4 bg-charcoal-800/70 rounded-xl border border-white/10">
          <p className="text-sm text-gray-400 mb-2">Total Assets</p>
          <p className="text-xl font-semibold text-white">
            {parseFloat(formatUnits(fleetInfo.totalAssets, assetDecimals)).toLocaleString('en-US', {
              minimumFractionDigits: 0,
              maximumFractionDigits: 6,
            })}{' '}
            {assetSymbol}
          </p>
        </div>
        <div className="p-4 bg-charcoal-800/70 rounded-xl border border-white/10">
          <div className="flex justify-between items-start mb-2">
            <p className="text-sm text-gray-400">Withdrawable Assets</p>
            <span className="text-xs bg-green-500/20 text-green-300 px-2 py-1 rounded-full border border-green-500/30">
              {fleetInfo.totalAssets > BigInt(0)
                ? (
                    (Number(fleetInfo.withdrawableTotalAssets) / Number(fleetInfo.totalAssets)) *
                    100
                  ).toFixed(1)
                : '0.0'}
              % available
            </span>
          </div>
          <p className="text-xl font-semibold text-white">
            {parseFloat(
              formatUnits(fleetInfo.withdrawableTotalAssets, assetDecimals),
            ).toLocaleString('en-US', {
              minimumFractionDigits: 0,
              maximumFractionDigits: 6,
            })}{' '}
            {assetSymbol}
          </p>
        </div>
      </div>

      {userInfo && (
        <div className="border-t border-gray-700 pt-4 mb-4">
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div className="p-3 bg-gray-800 rounded-lg">
              <p className="text-sm text-gray-400">Your Balance</p>
              <p className="font-semibold text-white">
                {formatDecimalOutput(userInfo.balance, 18)} {fleetInfo.symbol}
              </p>
            </div>
            <div className="p-3 bg-gray-800 rounded-lg">
              <p className="text-sm text-gray-400">Your {assetSymbol} Balance</p>
              <p className="font-semibold text-white">
                {formatDecimalOutput(userInfo.underlyingBalance, assetDecimals)} {assetSymbol}
              </p>
            </div>
          </div>

          {/* Show staked balance if staking is available */}
          {stakingRewardsManagerAddress && stakedBalance > BigInt(0) && (
            <div className="mb-4">
              <div className="p-3 bg-blue-900 border border-blue-700 rounded-lg">
                <p className="text-sm text-blue-300">Staked Balance</p>
                <p className="font-semibold text-blue-100">
                  {formatDecimalOutput(stakedBalance, 18)} {fleetInfo.symbol}
                </p>
                <p className="text-xs text-blue-400 mt-1">Earning additional rewards</p>
              </div>
            </div>
          )}

          <div className="mb-4">
            <label htmlFor="amount" className="block text-sm font-medium text-gray-300 mb-2">
              Amount
            </label>
            <input
              type="text"
              id="amount"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder={`Amount in ${assetSymbol}`}
              className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <div className="flex gap-3">
            <button
              onClick={handleDeposit}
              disabled={isApproveLoading || isDepositLoading || !amount}
              className={`flex-1 p-3 rounded-lg font-semibold transition-colors shadow-glow ${
                isApproveLoading || isDepositLoading || !amount
                  ? 'bg-magenta-700/40 text-gray-400 cursor-not-allowed'
                  : 'bg-magenta-600 hover:bg-magenta-700 text-white'
              }`}
            >
              {isApproveLoading
                ? 'Approving…'
                : isDepositLoading
                  ? 'Depositing…'
                  : needsApproval
                    ? 'Approve'
                    : 'Deposit'}
            </button>
            <button
              onClick={handleWithdraw}
              disabled={isWithdrawLoading || !amount}
              className={`flex-1 p-3 rounded-lg font-semibold transition-colors ${
                isWithdrawLoading || !amount
                  ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                  : 'bg-red-600 hover:bg-red-700 text-white'
              }`}
            >
              {isWithdrawLoading ? 'Withdrawing…' : 'Withdraw'}
            </button>
          </div>
        </div>
      )}

      <div className="text-right mt-4">
        <Link
          href={`/fleet/${chainId}/${fleetInfo.address}`}
          className="text-blue-400 hover:text-blue-300 text-sm font-medium transition-colors"
        >
          View Details →
        </Link>
      </div>
    </div>
  )
}
