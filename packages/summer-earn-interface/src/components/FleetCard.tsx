'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { formatUnits } from 'viem'
import { useAccount } from 'wagmi'

import { useFleetActions } from '../hooks/useFleetActions'
import { useFleetInfo } from '../hooks/useFleetInfo'
import { useStakingRewards } from '../hooks/useStakingRewards'
import { ChainId, FleetCommanderInfo, UserFleetInfo } from '../types'
import { formatDecimalOutput, parseDecimalInput } from '../utils/decimals'
import { ProgressBar } from './ProgressBar'

const MAX_UINT256 = BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')

interface FleetCardProps {
  fleetInfo: FleetCommanderInfo
  /** Optional: when provided (e.g. fleet detail page), use instead of fetching */
  userInfo?: UserFleetInfo | null
  assetDecimals: number
  assetSymbol: string
  chainId: string
}

export function FleetCard({
  fleetInfo,
  userInfo: userInfoProp,
  assetDecimals,
  assetSymbol,
  chainId,
}: FleetCardProps) {
  const [amount, setAmount] = useState<string>('')
  const { isConnected } = useAccount()

  const { userInfo: fetchedUserInfo, updateAllowance } = useFleetInfo({
    address: fleetInfo.address as `0x${string}`,
    chainId,
  })

  const userInfo = userInfoProp ?? (isConnected ? fetchedUserInfo : null)

  const {
    approve,
    deposit,
    withdraw,
    isApproveLoading,
    isDepositLoading,
    isWithdrawLoading,
    isApproveSuccess,
  } = useFleetActions({
    fleetAddress: fleetInfo.address as `0x${string}`,
    assetAddress: fleetInfo.asset as `0x${string}`,
    assetDecimals,
    chainId: chainId as ChainId,
  })

  useStakingRewards({
    fleetAddress: fleetInfo.address,
    chainId: chainId as ChainId,
  })

  useEffect(() => {
    if (isApproveSuccess) {
      updateAllowance(MAX_UINT256)
    }
  }, [isApproveSuccess, updateAllowance])

  const needsApproval = (() => {
    if (!userInfo || !amount || amount === '0') return false
    try {
      const parsedAmount = parseDecimalInput(amount, assetDecimals)
      return parsedAmount > BigInt(0) && userInfo.allowance < parsedAmount
    } catch {
      return false
    }
  })()

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

  const withdrawablePct =
    fleetInfo.totalAssets > BigInt(0)
      ? (Number(fleetInfo.withdrawableTotalAssets) / Number(fleetInfo.totalAssets)) * 100
      : 0

  const hasUserPosition = userInfo && userInfo.balance > BigInt(0)

  return (
    <div
      className={`glass rounded-xl p-6 transition-all hover:-translate-y-1 neon-glow group border-t-2 ${
        hasUserPosition ? 'border-t-primary/40 bg-primary/5' : 'border-t-transparent'
      }`}
    >
      <div className="flex justify-between items-start mb-6">
        <div className="flex items-center space-x-4">
          <div className="w-12 h-12 rounded-full overflow-hidden border-2 border-white/10 bg-black/20 flex items-center justify-center">
            <span className="text-lg font-bold text-primary">
              {fleetInfo.name.charAt(0)}
              {fleetInfo.symbol.charAt(0)}
            </span>
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h4 className="font-bold text-white text-lg">{fleetInfo.name}</h4>
              {hasUserPosition && (
                <span className="bg-primary text-[9px] px-1.5 py-0.5 rounded text-white uppercase font-bold tracking-tighter">
                  Active
                </span>
              )}
            </div>
            <p className="text-xs text-primary font-medium">{fleetInfo.symbol}</p>
          </div>
        </div>
        <div className="text-right">
          <p className="text-xs text-slate-500 mb-1">APY</p>
          <p className="text-xl font-bold text-green-400">—</p>
        </div>
      </div>

      <div className="space-y-4 mb-8">
        <div className="flex justify-between text-sm">
          <span className="text-slate-400">{hasUserPosition ? 'Your Deposit' : 'TVL'}</span>
          <span className="text-white font-medium">
            {hasUserPosition && userInfo
              ? `${formatDecimalOutput(userInfo.balance, fleetInfo.fleetDecimals ?? 18)} ${fleetInfo.symbol}`
              : `${parseFloat(formatUnits(fleetInfo.totalAssets, assetDecimals)).toLocaleString(
                  'en-US',
                  {
                    minimumFractionDigits: 0,
                    maximumFractionDigits: 2,
                  },
                )} ${assetSymbol}`}
          </span>
        </div>
        <div>
          <div className="flex justify-between text-sm mb-2">
            <span className="text-slate-400">Withdrawable</span>
            <span className="text-white font-medium">{withdrawablePct.toFixed(0)}%</span>
          </div>
          <ProgressBar value={withdrawablePct} showGlow={withdrawablePct > 80} />
        </div>
      </div>

      <div className="space-y-3">
        <div className="flex space-x-2">
          <div className="relative flex-1">
            <input
              type="text"
              inputMode="decimal"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className="w-full bg-black/40 border border-white/10 rounded-lg py-2.5 px-3 text-sm focus:border-primary/50 focus:ring-0 text-white"
            />
            {userInfo && (
              <button
                type="button"
                onClick={() =>
                  setAmount(formatDecimalOutput(userInfo.balance, fleetInfo.fleetDecimals ?? 18))
                }
                className="absolute right-2 top-1/2 -translate-y-1/2 text-[10px] font-bold text-primary bg-primary/10 px-1.5 py-0.5 rounded hover:bg-primary/20"
              >
                MAX
              </button>
            )}
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <button
            type="button"
            onClick={handleDeposit}
            disabled={isApproveLoading || isDepositLoading || !amount}
            className="bg-primary hover:bg-primary/90 text-white font-bold py-3 rounded-lg text-sm transition-all shadow-lg shadow-primary/10 disabled:opacity-50 disabled:cursor-not-allowed"
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
            type="button"
            onClick={handleWithdraw}
            disabled={isWithdrawLoading || !amount}
            className="bg-white/5 hover:bg-red-500/10 border border-white/10 hover:border-red-500/30 text-slate-300 hover:text-red-400 font-bold py-3 rounded-lg text-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isWithdrawLoading ? 'Withdrawing…' : 'Withdraw'}
          </button>
        </div>
      </div>

      <div className="text-right mt-4 pt-4 border-t border-white/5">
        <Link
          href={`/fleet/${chainId}/${fleetInfo.address}`}
          className="text-primary hover:text-primary/80 text-sm font-medium transition-colors"
        >
          View Details →
        </Link>
      </div>
    </div>
  )
}
