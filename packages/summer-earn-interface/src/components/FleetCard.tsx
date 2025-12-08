'use client'

import { useState } from 'react'
import Link from 'next/link'
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
    <div className="bg-charcoal-900/70 rounded-3xl p-7 mb-4 border border-white/10 shadow-xl backdrop-blur-md h-full flex flex-col justify-between">
      <div>
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-bold text-white">{fleetInfo.name}</h2>
          <span className="text-xs bg-violet-500/20 text-violet-300 py-1 px-2 rounded-full border border-violet-500/30 font-semibold">
            {fleetInfo.symbol}
          </span>
        </div>

        <div className="space-y-4 mb-6">
          <div className="p-4 bg-charcoal-800/50 rounded-xl border border-white/5">
            <p className="text-sm text-gray-400 mb-1">Total Assets</p>
            <p className="text-xl font-bold text-white">
              {parseFloat(formatUnits(fleetInfo.totalAssets, assetDecimals)).toLocaleString(
                'en-US',
                {
                  minimumFractionDigits: 0,
                  maximumFractionDigits: 6,
                },
              )}{' '}
              {assetSymbol}
            </p>
          </div>
          <div className="p-4 bg-charcoal-800/50 rounded-xl border border-white/5">
            <div className="flex justify-between items-start mb-1">
              <p className="text-sm text-gray-400">Withdrawable Assets</p>
              <span className="text-xs bg-emerald-500/20 text-emerald-300 px-2 py-0.5 rounded-full border border-emerald-500/30 font-medium">
                {fleetInfo.totalAssets > BigInt(0)
                  ? (
                      (Number(fleetInfo.withdrawableTotalAssets) / Number(fleetInfo.totalAssets)) *
                      100
                    ).toFixed(1)
                  : '0.0'}
                % available
              </span>
            </div>
            <p className="text-xl font-bold text-white">
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
          <div className="border-t border-white/5 pt-6 mb-4">
            <div className="grid grid-cols-2 gap-4 mb-4">
              <div className="p-3 bg-charcoal-800/50 rounded-xl border border-white/5">
                <p className="text-sm text-gray-400">Your Balance</p>
                <p className="font-bold text-white">
                  {formatDecimalOutput(userInfo.balance, 18)} {fleetInfo.symbol}
                </p>
              </div>
              <div className="p-3 bg-charcoal-800/50 rounded-xl border border-white/5">
                <p className="text-sm text-gray-400">Your {assetSymbol} Balance</p>
                <p className="font-bold text-white">
                  {formatDecimalOutput(userInfo.underlyingBalance, assetDecimals)} {assetSymbol}
                </p>
              </div>
            </div>

            {/* Show staked balance if staking is available */}
            {stakingRewardsManagerAddress && stakedBalance > BigInt(0) && (
              <div className="mb-4">
                <div className="p-4 bg-blue-900/20 border border-blue-500/30 rounded-xl">
                  <p className="text-sm text-blue-300">Staked Balance</p>
                  <p className="font-bold text-blue-100">
                    {formatDecimalOutput(stakedBalance, 18)} {fleetInfo.symbol}
                  </p>
                  <p className="text-xs text-blue-400/80 mt-1">Earning additional rewards</p>
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
                className="w-full p-3 bg-charcoal-800/50 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all"
              />
            </div>

            <div className="flex gap-3">
              <button
                onClick={handleDeposit}
                disabled={isApproveLoading || isDepositLoading || !amount}
                className={`flex-1 p-3 rounded-xl font-bold transition-all shadow-md ${
                  isApproveLoading || isDepositLoading || !amount
                    ? 'bg-gray-700 text-gray-400 cursor-not-allowed'
                    : 'bg-gradient-to-r from-purple-600 to-magenta-600 hover:from-purple-700 hover:to-magenta-700 text-white transform hover:-translate-y-0.5'
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
                className={`flex-1 p-3 rounded-xl font-bold transition-all shadow-md ${
                  isWithdrawLoading || !amount
                    ? 'bg-gray-700 text-gray-400 cursor-not-allowed'
                    : 'bg-gradient-to-r from-red-600 to-pink-600 hover:from-red-700 hover:to-pink-700 text-white transform hover:-translate-y-0.5'
                }`}
              >
                {isWithdrawLoading ? 'Withdrawing…' : 'Withdraw'}
              </button>
            </div>
          </div>
        )}
      </div>

      <div className="text-right mt-4 pt-4 border-t border-white/5">
        <Link
          href={`/fleet/${chainId}/${fleetInfo.address}`}
          className="inline-flex items-center text-blue-400 hover:text-blue-300 text-sm font-bold transition-colors group"
        >
          View Details
          <span className="ml-1 transition-transform group-hover:translate-x-1">→</span>
        </Link>
      </div>
    </div>
  )
}
