'use client'

import { useEffect, useMemo, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useAccount } from 'wagmi'

import { useLocalStorage } from '@/hooks/useLocalStorage'

import { useStakingAPR } from '../../../hooks/useStakingAPR'
import { useSummerStaking } from '../../../hooks/useSummerStaking'
import { useSyncWalletChain } from '../../../hooks/useSyncWalletChain'
import { useVestingWallets } from '../../../hooks/useVestingWallets'
import type { ChainId } from '../../../types'

const MAX_LOCKUP = 3 * 365 * 24 * 60 * 60 // seconds
const FIXED_PENALTY_PERIOD = 110 * 24 * 60 * 60

function formatDays(seconds: bigint | number) {
  const s = typeof seconds === 'number' ? seconds : Number(seconds)
  const d = Math.floor(s / (24 * 60 * 60))
  return `${d}d`
}

function formatAmount(a: bigint, decimals: number) {
  const neg = a < 0n
  const x = neg ? -a : a
  const base = 10n ** BigInt(decimals)
  const i = x / base
  const f = x % base
  const fStr = f.toString().padStart(decimals, '0').replace(/0+$/, '')
  return `${neg ? '-' : ''}${i.toString()}${fStr ? '.' + fStr : ''}`
}

function formatMultiplier(wad: bigint) {
  // wad is 1e18-scaled multiplier
  const int = wad / 1000000000000000000n
  const frac = wad % 1000000000000000000n
  const fracStr = frac.toString().padStart(18, '0').slice(0, 2).replace(/0+$/, '') || '0'
  return `${int.toString()}.${fracStr}x`
}

function formatAmountFixed(a: bigint, decimals: number, dp: number) {
  const base = 10n ** BigInt(decimals)
  const i = a / base
  const rem = a % base
  if (dp <= 0) return i.toString()
  if (dp >= decimals) {
    const scale = 10n ** BigInt(dp - decimals)
    const frac = (rem * scale).toString().padStart(dp, '0')
    return `${i.toString()}.${frac}`
  }
  const scale = 10n ** BigInt(decimals - dp)
  const frac = (rem / scale).toString().padStart(dp, '0')
  return `${i.toString()}.${frac}`
}

export default function SummerStakingPage() {
  const params = useParams()
  const router = useRouter()
  const chainId = params.chainId as ChainId
  const [selectedChain, _setSelectedChain] = useLocalStorage<ChainId>('selectedChain', chainId)

  useSyncWalletChain(selectedChain)

  // APR calculation hook
  const { apr, annualRewardAmount, annualRewardValue, totalStakedValue, isActive } = useStakingAPR(
    selectedChain as ChainId,
  )

  const { isConnected, address: account } = useAccount()

  const {
    summerAddress,
    xSummerAddress,
    stakingAddress,
    summerDecimals,
    summerSymbol,
    buckets,
    stakes,
    currentOverallMultiplierWad,
    summerBalance,
    xSummerBalance,
    approveSummer,
    approveXSummer,
    stakeLockup,
    unstakeLockup,
    needsSummerApproval,
    needsXSummerApproval,
    isPending,
    isConfirming,
  } = useSummerStaking(selectedChain as ChainId)

  const [amountStr, setAmountStr] = useState('')
  const [amount, setAmount] = useState<bigint>(0n)
  const [lockup, setLockup] = useState<number>(0)
  const [unstakeIndex, setUnstakeIndex] = useState<number>(0)
  const [unstakeAmountStr, setUnstakeAmountStr] = useState('')
  const [unstakeAmount, setUnstakeAmount] = useState<bigint>(0n)
  const [nowTs, setNowTs] = useState<number>(Math.floor(Date.now() / 1000))

  // Vesting wallet state
  const {
    escrowAddress,
    factoryV2Address,
    userVestingWallet,
    enabledFactories,
    isOwnedByEscrow,
    isFactoryStaked,
    vestingWalletBalance,
    vestingWalletReleased,
    summerBalance: vestingSummerBalance,
    needsFactoryApproval,
    needsEscrowApproval,
    createVestingWallet,
    approveFactory,
    approveEscrow,
    transferOwnershipToEscrow,
    stakeVesting,
    unstakeVesting,
    addFactory,
    isPending: isVestingPending,
    isConfirming: isVestingConfirming,
  } = useVestingWallets(selectedChain as ChainId)

  const [vestingCliffEnd, setVestingCliffEnd] = useState<number>(
    Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
  )
  const [vestingCliffAmount, setVestingCliffAmount] = useState<bigint>(0n)
  const [vestingCliffAmountStr, setVestingCliffAmountStr] = useState('')
  const [vestingPeriods, setVestingPeriods] = useState<number>(12)
  const [vestingTotalAmount, setVestingTotalAmount] = useState<bigint>(0n)
  const [vestingTotalAmountStr, setVestingTotalAmountStr] = useState('')
  const [vestingBeneficiary, setVestingBeneficiary] = useState<string>('')
  const [newFactoryAddress, setNewFactoryAddress] = useState('')

  const onVestingCliffAmountChange = (v: string) => {
    setVestingCliffAmountStr(v)
    try {
      if (!v) return setVestingCliffAmount(0n)
      const [i, f = ''] = v.split('.')
      const fPad = (f + '0'.repeat(summerDecimals)).slice(0, summerDecimals)
      const bi = BigInt(i || '0')
      const bf = BigInt(fPad || '0')
      const base = 10n ** BigInt(summerDecimals)
      setVestingCliffAmount(bi * base + bf)
    } catch {
      setVestingCliffAmount(0n)
    }
  }

  const onVestingTotalAmountChange = (v: string) => {
    setVestingTotalAmountStr(v)
    try {
      if (!v) return setVestingTotalAmount(0n)
      const [i, f = ''] = v.split('.')
      const fPad = (f + '0'.repeat(summerDecimals)).slice(0, summerDecimals)
      const bi = BigInt(i || '0')
      const bf = BigInt(fPad || '0')
      const base = 10n ** BigInt(summerDecimals)
      setVestingTotalAmount(bi * base + bf)
    } catch {
      setVestingTotalAmount(0n)
    }
  }

  const totalVestingNeeded = vestingCliffAmount + vestingTotalAmount
  const isValidBeneficiary =
    vestingBeneficiary === '' ||
    (/^0x[a-fA-F0-9]{40}$/.test(vestingBeneficiary) &&
      vestingBeneficiary.toLowerCase() !== account?.toLowerCase())
  const beneficiaryAddress = vestingBeneficiary ? (vestingBeneficiary as `0x${string}`) : account
  const canCreateVesting =
    isConnected &&
    totalVestingNeeded > 0n &&
    vestingSummerBalance >= totalVestingNeeded &&
    !needsFactoryApproval(totalVestingNeeded) &&
    isValidBeneficiary &&
    !!beneficiaryAddress

  const handleCreateVesting = async () => {
    if (!beneficiaryAddress || !canCreateVesting) return
    try {
      await createVestingWallet(
        beneficiaryAddress,
        {
          cliffEndTimestamp: vestingCliffEnd,
          cliffAmount: vestingCliffAmount,
          vestingPeriods: BigInt(vestingPeriods),
          totalVestingAmount: vestingTotalAmount,
        },
        [],
      )
    } catch (error) {
      console.error('Failed to create vesting wallet:', error)
    }
  }

  const handleStakeVesting = async () => {
    if (!factoryV2Address) return
    try {
      await stakeVesting([factoryV2Address as `0x${string}`])
    } catch (error) {
      console.error('Failed to stake vesting wallet:', error)
    }
  }

  const handleUnstakeVesting = async () => {
    if (!factoryV2Address) return
    try {
      await unstakeVesting([factoryV2Address as `0x${string}`])
    } catch (error) {
      console.error('Failed to unstake vesting wallet:', error)
    }
  }

  useEffect(() => {
    const id = setInterval(() => setNowTs(Math.floor(Date.now() / 1000)), 1000)
    return () => clearInterval(id)
  }, [])

  const onAmountChange = (v: string) => {
    setAmountStr(v)
    try {
      if (!v) return setAmount(0n)
      const [i, f = ''] = v.split('.')
      const fPad = (f + '0'.repeat(summerDecimals)).slice(0, summerDecimals)
      const bi = BigInt(i || '0')
      const bf = BigInt(fPad || '0')
      const base = 10n ** BigInt(summerDecimals)
      setAmount(bi * base + bf)
    } catch {
      setAmount(0n)
    }
  }

  const onUnstakeAmountChange = (v: string) => {
    setUnstakeAmountStr(v)
    try {
      if (!v) return setUnstakeAmount(0n)
      const [i, f = ''] = v.split('.')
      const fPad = (f + '0'.repeat(summerDecimals)).slice(0, summerDecimals)
      const bi = BigInt(i || '0')
      const bf = BigInt(fPad || '0')
      const base = 10n ** BigInt(summerDecimals)
      setUnstakeAmount(bi * base + bf)
    } catch {
      setUnstakeAmount(0n)
    }
  }

  const previewMultiplierWad = useMemo(() => {
    if (amount <= 0n) return 1000000000000000000n
    // multiplier approx: 1 + 7e-16 * t^2 (t in seconds). We'll compute via JS for display only.
    const t = BigInt(lockup)
    const t2 = t * t
    const coeff = 700n // matches solidity coefficient with 1e18 scale applied internally
    // wad: 1e18 + coeff * t^2 (but coeff here is 700, representing 7e-16*1e18)
    const wad = 1000000000000000000n + coeff * t2
    return wad
  }, [amount, lockup])

  const projectedOverallMultiplierWad = useMemo(() => {
    if (amount <= 0n) return currentOverallMultiplierWad
    const newAmount = stakes.reduce((s, x) => s + x.amount, 0n) + amount
    const newWeighted =
      stakes.reduce((s, x) => s + x.weightedAmount, 0n) +
      (amount * previewMultiplierWad) / 1000000000000000000n
    return newAmount > 0n ? (newWeighted * 1000000000000000000n) / newAmount : 1000000000000000000n
  }, [stakes, amount, previewMultiplierWad, currentOverallMultiplierWad])

  // Penalty chart points (simple SVG) scaled to selected lockup period
  const penaltyChart = useMemo(() => {
    const steps = 64
    const duration = Math.max(0, lockup)
    const points: { x: number; y: number }[] = []
    for (let i = 0; i <= steps; i++) {
      const t = Math.floor((i / steps) * duration)
      let pct = 0
      if (t < FIXED_PENALTY_PERIOD) {
        pct = 2
      } else {
        pct = 2 + (18 * (t - FIXED_PENALTY_PERIOD)) / (MAX_LOCKUP - FIXED_PENALTY_PERIOD)
      }
      points.push({ x: i, y: pct })
    }
    const startPct = points[points.length - 1]?.y ?? 2
    const tickIdx = [0, Math.floor(steps / 3), Math.floor((2 * steps) / 3), steps]
    const ticks = tickIdx.map((idx) => {
      const tSec = Math.floor((idx / steps) * duration)
      return { x: idx, label: formatDays(tSec) }
    })
    return { points, startPct, ticks }
  }, [lockup])

  const canStake = isConnected && amount > 0n
  const canUnstake = isConnected && unstakeAmount > 0n
  const canApproveEnabled = isConnected && amount > 0n

  const selectedStake = useMemo(
    () => stakes.find((s) => s.index === unstakeIndex) || null,
    [stakes, unstakeIndex],
  )

  const penaltyInfoFor = (amt: bigint, endTime: bigint) => {
    const remaining = Number(endTime) - nowTs
    if (remaining <= 0) return { pct: 0, pctWad: 0n, amount: 0n, remaining }
    const MAX = MAX_LOCKUP
    let pct = 0
    if (remaining < FIXED_PENALTY_PERIOD) {
      pct = 0.02
    } else {
      pct = (remaining / MAX) * 0.2
    }
    const pctWad = BigInt(Math.floor(pct * 1e18))
    const penaltyAmt = (amt * pctWad) / 1000000000000000000n
    return { pct, pctWad, amount: penaltyAmt, remaining }
  }

  return (
    <main className="min-h-screen bg-charcoal-900 p-6 md:p-10">
      <div className="max-w-5xl mx-auto space-y-6">
        <div className="flex items-center gap-4 mb-2">
          <button
            onClick={() => router.back()}
            className="px-4 py-2 bg-charcoal-800 hover:bg-gray-700 text-white rounded-lg border border-white/10"
          >
            ← Back
          </button>
          <h1 className="text-3xl md:text-4xl font-extrabold text-white">Summer Staking</h1>
        </div>

        {/* Staking APR */}
        <div className="rounded-2xl p-6 bg-charcoal-900 border border-white/10">
          <h2 className="text-xl font-semibold text-white mb-4">Staking Rewards</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="p-4 bg-charcoal-800 rounded border border-white/10">
              <div className="text-xs text-gray-400 mb-1">Current APR</div>
              <div className="text-2xl font-bold text-magenta-400">
                {apr > 0 ? `${apr.toFixed(2)}%` : '—'}
              </div>
              <div className="text-xs text-gray-400 mt-1">{isActive ? 'Active' : 'Inactive'}</div>
            </div>
            <div className="p-4 bg-charcoal-800 rounded border border-white/10">
              <div className="text-xs text-gray-400 mb-1">Annual Rewards</div>

              <div className="text-lg font-semibold text-white">
                {annualRewardAmount > 0 ? annualRewardAmount.toFixed(2) : '—'}
              </div>
              <div className="text-xs text-gray-400 mt-1">{summerSymbol}</div>
            </div>
            <div className="p-4 bg-charcoal-800 rounded border border-white/10">
              <div className="text-xs text-gray-400 mb-1">Annual Value</div>
              <div className="text-lg font-semibold text-green-400">
                {annualRewardValue > 0 ? `$${annualRewardValue.toFixed(2)}` : '—'}
              </div>
              <div className="text-xs text-gray-400 mt-1">USD</div>
            </div>
            <div className="p-4 bg-charcoal-800 rounded border border-white/10">
              <div className="text-xs text-gray-400 mb-1">Total Staked Value</div>
              <div className="text-lg font-semibold text-blue-400">
                {totalStakedValue > 0 ? `$${totalStakedValue.toFixed(2)}` : '—'}
              </div>
              <div className="text-xs text-gray-400 mt-1">USD</div>
            </div>
          </div>
        </div>

        {/* Wallet Balances */}
        {isConnected && (
          <div className="rounded-2xl p-4 bg-charcoal-800 border border-white/10">
            <h2 className="text-lg font-semibold text-white mb-3">Your Balances</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="p-3 bg-charcoal-900 rounded border border-white/10">
                <div className="text-xs text-gray-400 mb-1">{summerSymbol} Balance</div>
                <div className="text-xl font-semibold text-white">
                  {formatAmount(summerBalance, summerDecimals)}
                </div>
              </div>
              <div className="p-3 bg-charcoal-900 rounded border border-white/10">
                <div className="text-xs text-gray-400 mb-1">xSUMR Balance</div>
                <div className="text-xl font-semibold text-white">
                  {formatAmount(xSummerBalance, summerDecimals)}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Buckets */}
        <div className="rounded-2xl p-6 bg-charcoal-900 border border-white/10">
          <h2 className="text-xl font-semibold text-white mb-4">Lockup Buckets</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
            {buckets.map((b, i) => (
              <div key={i} className="p-4 rounded-lg bg-charcoal-800 border border-white/10">
                <div className="flex justify-between items-center mb-2">
                  <div className="text-gray-300">Bucket #{b.key}</div>
                  <div className={`px-2 py-0.5 text-xs rounded ${b.color} text-white`}>
                    {b.remainingPct.toFixed(0)}% left
                  </div>
                </div>
                <div className="text-sm text-gray-400">
                  Range: {formatDays(b.min)} - {formatDays(b.max)}
                </div>
                <div className="mt-2 h-2 bg-gray-700 rounded">
                  {b.cap > 0n && (
                    <div
                      className={`${b.color} h-2 rounded`}
                      style={{ width: `${Math.max(0, 100 - b.remainingPct)}%` }}
                    />
                  )}
                </div>
                <div className="mt-2 text-xs text-gray-400">
                  Staked:{' '}
                  <span className="text-white">
                    {formatAmountFixed(b.staked, summerDecimals, 2)} {summerSymbol}
                  </span>
                </div>
                <div className="text-xs text-gray-400">
                  Cap:{' '}
                  <span className="text-white">
                    {b.cap === 0n
                      ? 'Disabled'
                      : b.cap.toString() ===
                          '115792089237316195423570985008687907853269984665640564039457584007913129639935'
                        ? 'Unlimited'
                        : `${formatAmountFixed(b.cap, summerDecimals, 2)} ${summerSymbol}`}
                  </span>
                </div>
                {b.cap === 0n && <div className="text-xs text-gray-500 mt-1">Disabled</div>}
              </div>
            ))}
          </div>
        </div>

        {/* Stake */}
        <div className="grid gap-6 md:grid-cols-2">
          <div className="rounded-2xl p-6 bg-charcoal-900 border border-white/10 space-y-4">
            <h2 className="text-xl font-semibold text-white">Stake</h2>
            <div>
              <label className="block text-sm text-gray-300 mb-1">Amount ({summerSymbol})</label>
              <input
                value={amountStr}
                onChange={(e) => onAmountChange(e.target.value)}
                placeholder={`0.0`}
                className="w-full px-3 py-2 bg-charcoal-800 border border-white/10 rounded text-white"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-300 mb-1">
                Lockup Period: {formatDays(lockup)}
              </label>
              <input
                type="range"
                min={0}
                max={MAX_LOCKUP}
                step={24 * 60 * 60}
                value={lockup}
                onChange={(e) => setLockup(Number(e.target.value))}
                className="w-full"
              />
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="p-3 bg-charcoal-800 rounded border border-white/10">
                <div className="text-xs text-gray-400">Current multiplier</div>
                <div className="text-lg text-white font-semibold">
                  {formatMultiplier(currentOverallMultiplierWad)}
                </div>
              </div>
              <div className="p-3 bg-charcoal-800 rounded border border-white/10">
                <div className="text-xs text-gray-400">New stake multiplier</div>
                <div className="text-lg text-white font-semibold">
                  {amount > 0n ? formatMultiplier(previewMultiplierWad) : '—'}
                </div>
              </div>
              <div className="p-3 bg-charcoal-800 rounded border border-white/10">
                <div className="text-xs text-gray-400">Projected overall</div>
                <div className="text-lg text-white font-semibold">
                  {formatMultiplier(projectedOverallMultiplierWad)}
                </div>
              </div>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => approveSummer()}
                disabled={!canApproveEnabled || isPending || isConfirming}
                className={`px-4 py-2 rounded ${canApproveEnabled && !isPending && !isConfirming ? 'bg-magenta-600 hover:bg-magenta-700' : 'bg-gray-700 text-gray-400 cursor-not-allowed'} text-white`}
              >
                Approve {summerSymbol}
              </button>
              <button
                onClick={() => stakeLockup(amount, BigInt(lockup))}
                disabled={!canStake || needsSummerApproval(amount) || isPending || isConfirming}
                className={`px-4 py-2 rounded ${canStake && !needsSummerApproval(amount) && !isPending && !isConfirming ? 'bg-magenta-600 hover:bg-magenta-700' : 'bg-gray-700 text-gray-400 cursor-not-allowed'} text-white`}
              >
                {isPending || isConfirming ? 'Submitting…' : 'Stake'}
              </button>
            </div>

            {/* Penalty chart */}
            <div className="mt-2">
              <div className="text-sm text-gray-300 mb-2">Early Unstake Penalty</div>
              {(() => {
                const chartWidth = penaltyChart.points.length - 1
                const margin = 4 // add some horizontal breathing room so edge labels are visible
                return (
                  <svg
                    viewBox={`-${margin} 0 ${chartWidth + margin * 2} 26`}
                    className="w-full h-48 bg-gray-800 rounded"
                  >
                    <polyline
                      fill="none"
                      stroke="#ff2d8f"
                      strokeWidth="0.5"
                      points={penaltyChart.points
                        .map((p) => `${chartWidth - p.x},${20 - p.y}`)
                        .join(' ')}
                    />
                    <line
                      x1={String(-margin)}
                      y1="20"
                      x2={String(chartWidth + margin)}
                      y2="20"
                      stroke="#374151"
                      strokeWidth="0.3"
                    />
                    <text x={String(1 - margin / 2)} y="3" fontSize="2" fill="#9ca3af">
                      {penaltyChart.startPct.toFixed(1)}%
                    </text>
                    <text
                      x={String(chartWidth - 3 + margin / 2)}
                      y="19"
                      fontSize="2"
                      fill="#9ca3af"
                    >
                      2%
                    </text>
                    {penaltyChart.ticks.map((t, i) => (
                      <g key={i}>
                        <line
                          x1={`${chartWidth - t.x}`}
                          y1="20"
                          x2={`${chartWidth - t.x}`}
                          y2="21.5"
                          stroke="#9ca3af"
                          strokeWidth="0.2"
                        />
                        <text
                          x={`${chartWidth - t.x}`}
                          y="25"
                          fontSize="2"
                          fill="#9ca3af"
                          textAnchor="middle"
                        >
                          {t.label}
                        </text>
                      </g>
                    ))}
                  </svg>
                )
              })()}
              <div className="text-xs text-gray-400 mt-1">
                Flat 2% if remaining &lt; 110 days. Linear to 20% at 3 years.
              </div>
            </div>
          </div>

          {/* Unstake */}
          <div className="rounded-2xl p-6 bg-charcoal-900 border border-white/10 space-y-4">
            <h2 className="text-xl font-semibold text-white">Unstake</h2>
            <div>
              <label className="block text-sm text-gray-300 mb-1">Select Stake</label>
              <select
                value={unstakeIndex}
                onChange={(e) => setUnstakeIndex(Number(e.target.value))}
                className="w-full px-3 py-2 bg-charcoal-800 border border-white/10 rounded text-white"
              >
                {stakes.map((s) => (
                  <option key={s.index} value={s.index}>
                    #{s.index} • {formatDays(s.lockupPeriod)} • amount{' '}
                    {formatAmount(s.amount, summerDecimals)} {summerSymbol} • multiplier{' '}
                    {formatMultiplier(s.multiplierWad)}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm text-gray-300 mb-1">Amount ({summerSymbol})</label>
              <div className="flex gap-2">
                <input
                  value={unstakeAmountStr}
                  onChange={(e) => onUnstakeAmountChange(e.target.value)}
                  placeholder={`0.0`}
                  className="flex-1 px-3 py-2 bg-charcoal-800 border border-white/10 rounded text-white"
                />
                <button
                  type="button"
                  onClick={() => {
                    if (!selectedStake) return
                    setUnstakeAmount(selectedStake.amount)
                    setUnstakeAmountStr(formatAmount(selectedStake.amount, summerDecimals))
                  }}
                  className="px-3 py-2 bg-magenta-600 hover:bg-magenta-700 text-white rounded"
                >
                  Max
                </button>
              </div>
            </div>
            {selectedStake && (
              <div className="text-sm text-gray-300 space-y-1">
                <div>
                  Stake amount:{' '}
                  <span className="text-white">
                    {formatAmount(selectedStake.amount, summerDecimals)} {summerSymbol}
                  </span>
                </div>
                <div>
                  Time remaining:{' '}
                  <span className="text-white">
                    {formatDays(Number(selectedStake.lockupEndTime) - nowTs)}
                  </span>
                </div>
                {(() => {
                  const p = penaltyInfoFor(
                    unstakeAmount > 0n ? unstakeAmount : selectedStake.amount,
                    selectedStake.lockupEndTime,
                  )
                  const pctStr = (p.pct * 100).toFixed(4)
                  return (
                    <div>
                      Current penalty: <span className="text-red-400">{pctStr}%</span> →{' '}
                      {formatAmountFixed(p.amount, summerDecimals, 4)} {summerSymbol}
                    </div>
                  )
                })()}
              </div>
            )}
            <div className="flex gap-3">
              <button
                onClick={() => approveXSummer()}
                disabled={!canUnstake || !needsXSummerApproval(unstakeAmount)}
                className={`px-4 py-2 rounded ${canUnstake && needsXSummerApproval(unstakeAmount) ? 'bg-magenta-600 hover:bg-magenta-700' : 'bg-gray-700 text-gray-400 cursor-not-allowed'} text-white`}
              >
                Approve xSUMR
              </button>
              <button
                onClick={() => unstakeLockup(unstakeIndex, unstakeAmount)}
                disabled={
                  !canUnstake || needsXSummerApproval(unstakeAmount) || isPending || isConfirming
                }
                className={`px-4 py-2 rounded ${canUnstake && !needsXSummerApproval(unstakeAmount) && !isPending && !isConfirming ? 'bg-magenta-600 hover:bg-magenta-700' : 'bg-gray-700 text-gray-400 cursor-not-allowed'} text-white`}
              >
                {isPending || isConfirming ? 'Submitting…' : 'Unstake'}
              </button>
            </div>
            <div className="text-xs text-gray-400">Penalty will apply if lockup not expired.</div>
          </div>
        </div>

        {/* Stakes list */}
        <div className="rounded-2xl p-6 bg-charcoal-900 border border-white/10">
          <h2 className="text-xl font-semibold text-white mb-4">Your Stakes</h2>
          {stakes.length === 0 ? (
            <div className="text-gray-400">No stakes yet.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm text-left">
                <thead className="text-gray-400">
                  <tr>
                    <th className="p-2">Index</th>
                    <th className="p-2">Amount</th>
                    <th className="p-2">Lockup</th>
                    <th className="p-2">Ends</th>
                    <th className="p-2">Penalty</th>
                    <th className="p-2">Multiplier</th>
                  </tr>
                </thead>
                <tbody className="text-gray-200">
                  {stakes.map((s) => (
                    <tr key={s.index} className="border-t border-gray-800">
                      <td className="p-2">{s.index}</td>
                      <td className="p-2">
                        {formatAmount(s.amount, summerDecimals)} {summerSymbol}
                      </td>
                      <td className="p-2">{formatDays(s.lockupPeriod)}</td>
                      <td className="p-2">
                        {new Date(Number(s.lockupEndTime) * 1000).toLocaleDateString()}
                      </td>
                      <td className="p-2">
                        {(() => {
                          const p = penaltyInfoFor(s.amount, s.lockupEndTime)
                          const pctStr = (p.pct * 100).toFixed(4)
                          return (
                            <span>
                              {pctStr}% • {formatAmountFixed(p.amount, summerDecimals, 4)}{' '}
                              {summerSymbol}
                            </span>
                          )
                        })()}
                      </td>
                      <td className="p-2">{formatMultiplier(s.multiplierWad)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Vesting Wallet Section */}
        <div className="rounded-2xl p-6 bg-charcoal-900 border border-white/10 space-y-6">
          <h2 className="text-2xl font-semibold text-white">Vesting Wallet Staking</h2>

          {/* Your Vesting Wallet (if exists) */}
          {userVestingWallet && (
            <div className="rounded-xl p-4 bg-charcoal-800 border border-white/10 space-y-4">
              <h3 className="text-lg font-semibold text-white">Your Vesting Wallet</h3>
              <div className="text-sm text-gray-300 space-y-2">
                <div>
                  Vesting Wallet:{' '}
                  <span className="font-mono text-blue-300">{userVestingWallet}</span>
                </div>
                <div>
                  Balance:{' '}
                  <span className="text-white">
                    {formatAmount(vestingWalletBalance || 0n, summerDecimals)} {summerSymbol}
                  </span>
                </div>
                <div>
                  Released:{' '}
                  <span className="text-white">
                    {formatAmount(vestingWalletReleased || 0n, summerDecimals)} {summerSymbol}
                  </span>
                </div>
                <div>
                  Owner:{' '}
                  <span className={isOwnedByEscrow ? 'text-green-400' : 'text-yellow-400'}>
                    {isOwnedByEscrow ? 'Escrow' : 'You'}
                  </span>
                </div>
                {!isOwnedByEscrow && (
                  <button
                    onClick={() => transferOwnershipToEscrow()}
                    disabled={isVestingPending || isVestingConfirming}
                    className="px-4 py-2 bg-yellow-600 hover:bg-yellow-700 disabled:bg-gray-700 disabled:text-gray-400 disabled:cursor-not-allowed text-white rounded"
                  >
                    Transfer Ownership to Escrow
                  </button>
                )}
              </div>
            </div>
          )}

          {/* Create Vesting Wallet */}
          <div className="rounded-xl p-4 bg-charcoal-800 border border-white/10 space-y-4">
            <h3 className="text-lg font-semibold text-white">Create Vesting Wallet</h3>
            <>
              <div>
                <label className="block text-sm text-gray-300 mb-1">
                  Beneficiary Address (optional, defaults to connected wallet)
                </label>
                <input
                  value={vestingBeneficiary}
                  onChange={(e) => setVestingBeneficiary(e.target.value)}
                  placeholder={account || '0x...'}
                  className="w-full px-3 py-2 bg-charcoal-700 border border-white/10 rounded text-white font-mono text-sm"
                />
                {vestingBeneficiary && !isValidBeneficiary && (
                  <div className="text-xs text-red-400 mt-1">Invalid address format</div>
                )}
                {vestingBeneficiary && isValidBeneficiary && (
                  <div className="text-xs text-green-400 mt-1">✓ Valid address</div>
                )}
              </div>
              <div>
                <label className="block text-sm text-gray-300 mb-1">Cliff End Date</label>
                <input
                  type="datetime-local"
                  value={new Date(vestingCliffEnd * 1000).toISOString().slice(0, 16)}
                  onChange={(e) =>
                    setVestingCliffEnd(Math.floor(new Date(e.target.value).getTime() / 1000))
                  }
                  className="w-full px-3 py-2 bg-charcoal-700 border border-white/10 rounded text-white"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-300 mb-1">
                  Cliff Amount ({summerSymbol})
                </label>
                <input
                  value={vestingCliffAmountStr}
                  onChange={(e) => onVestingCliffAmountChange(e.target.value)}
                  placeholder="0.0"
                  className="w-full px-3 py-2 bg-charcoal-700 border border-white/10 rounded text-white"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-300 mb-1">Vesting Periods</label>
                <input
                  type="number"
                  min="1"
                  value={vestingPeriods}
                  onChange={(e) => setVestingPeriods(Number(e.target.value))}
                  className="w-full px-3 py-2 bg-charcoal-700 border border-white/10 rounded text-white"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-300 mb-1">
                  Total Vesting Amount ({summerSymbol})
                </label>
                <input
                  value={vestingTotalAmountStr}
                  onChange={(e) => onVestingTotalAmountChange(e.target.value)}
                  placeholder="0.0"
                  className="w-full px-3 py-2 bg-charcoal-700 border border-white/10 rounded text-white"
                />
              </div>
              <div className="text-sm text-gray-400">
                Total needed:{' '}
                <span className="text-white">
                  {formatAmount(totalVestingNeeded, summerDecimals)} {summerSymbol}
                </span>
                {vestingSummerBalance < totalVestingNeeded && (
                  <span className="text-red-400 ml-2">
                    (Insufficient balance: {formatAmount(vestingSummerBalance, summerDecimals)})
                  </span>
                )}
              </div>
              <div className="flex gap-3">
                <button
                  onClick={() => approveFactory()}
                  disabled={
                    !isConnected ||
                    totalVestingNeeded === 0n ||
                    !needsFactoryApproval(totalVestingNeeded) ||
                    isVestingPending ||
                    isVestingConfirming
                  }
                  className={`px-4 py-2 rounded ${
                    isConnected &&
                    totalVestingNeeded > 0n &&
                    needsFactoryApproval(totalVestingNeeded) &&
                    !isVestingPending &&
                    !isVestingConfirming
                      ? 'bg-magenta-600 hover:bg-magenta-700'
                      : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                  } text-white`}
                >
                  {isVestingPending || isVestingConfirming
                    ? 'Approving...'
                    : `Approve ${summerSymbol}`}
                </button>
                <button
                  onClick={handleCreateVesting}
                  disabled={!canCreateVesting || isVestingPending || isVestingConfirming}
                  className={`px-4 py-2 rounded ${
                    canCreateVesting && !isVestingPending && !isVestingConfirming
                      ? 'bg-magenta-600 hover:bg-magenta-700'
                      : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                  } text-white`}
                >
                  {isVestingPending || isVestingConfirming
                    ? 'Creating...'
                    : 'Create Vesting Wallet'}
                </button>
              </div>
            </>
          </div>

          {/* Stake/Unstake Vesting Wallet */}
          {userVestingWallet && (
            <div className="rounded-xl p-4 bg-charcoal-800 border border-white/10 space-y-4">
              <h3 className="text-lg font-semibold text-white">Stake/Unstake Vesting Wallet</h3>
              {isFactoryStaked ? (
                <div className="space-y-3">
                  <div className="text-sm text-green-400">✓ Vesting wallet is staked in escrow</div>
                  {needsEscrowApproval(vestingWalletBalance || 0n) && (
                    <div className="text-sm text-yellow-400">
                      ⚠ Approve xSUMR to unstake (escrow needs to burn your xSUMR tokens)
                    </div>
                  )}
                  <div className="flex gap-3">
                    <button
                      onClick={() => approveEscrow()}
                      disabled={
                        !isConnected ||
                        vestingWalletBalance === 0n ||
                        !needsEscrowApproval(vestingWalletBalance || 0n) ||
                        isVestingPending ||
                        isVestingConfirming
                      }
                      className={`px-4 py-2 rounded ${
                        isConnected &&
                        vestingWalletBalance > 0n &&
                        needsEscrowApproval(vestingWalletBalance || 0n) &&
                        !isVestingPending &&
                        !isVestingConfirming
                          ? 'bg-magenta-600 hover:bg-magenta-700'
                          : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                      } text-white`}
                    >
                      {isVestingPending || isVestingConfirming ? 'Approving...' : 'Approve xSUMR'}
                    </button>
                    <button
                      onClick={handleUnstakeVesting}
                      disabled={
                        isVestingPending ||
                        isVestingConfirming ||
                        needsEscrowApproval(vestingWalletBalance || 0n)
                      }
                      className={`px-4 py-2 rounded ${
                        !isVestingPending &&
                        !isVestingConfirming &&
                        !needsEscrowApproval(vestingWalletBalance || 0n)
                          ? 'bg-red-600 hover:bg-red-700'
                          : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                      } text-white`}
                    >
                      {isVestingPending || isVestingConfirming
                        ? 'Unstaking...'
                        : 'Unstake Vesting Wallet'}
                    </button>
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  {!isOwnedByEscrow && (
                    <div className="text-sm text-yellow-400">
                      ⚠ Transfer ownership to escrow first before staking
                    </div>
                  )}
                  {factoryV2Address &&
                  enabledFactories.some(
                    (f) => f.toLowerCase() === factoryV2Address.toLowerCase(),
                  ) ? (
                    <button
                      onClick={handleStakeVesting}
                      disabled={!isOwnedByEscrow || isVestingPending || isVestingConfirming}
                      className={`px-4 py-2 rounded ${
                        isOwnedByEscrow && !isVestingPending && !isVestingConfirming
                          ? 'bg-magenta-600 hover:bg-magenta-700'
                          : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                      } text-white`}
                    >
                      {isVestingPending || isVestingConfirming
                        ? 'Staking...'
                        : 'Stake Vesting Wallet'}
                    </button>
                  ) : (
                    <div className="text-sm text-red-400">Factory not enabled in escrow</div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Admin: Add Factory */}
          {escrowAddress && (
            <div className="rounded-xl p-4 bg-charcoal-800 border border-white/10 space-y-4">
              <h3 className="text-lg font-semibold text-white">Admin: Manage Factories</h3>
              <div>
                <label className="block text-sm text-gray-300 mb-1">Enabled Factories</label>
                <div className="space-y-1 text-xs text-gray-400">
                  {enabledFactories.length === 0 ? (
                    <div>No factories enabled</div>
                  ) : (
                    enabledFactories.map((factory, i) => (
                      <div key={i} className="font-mono text-blue-300">
                        {factory}
                      </div>
                    ))
                  )}
                </div>
              </div>
              <div>
                <label className="block text-sm text-gray-300 mb-1">Add Factory Address</label>
                <div className="flex gap-2">
                  <input
                    value={newFactoryAddress}
                    onChange={(e) => setNewFactoryAddress(e.target.value)}
                    placeholder="0x..."
                    className="flex-1 px-3 py-2 bg-charcoal-700 border border-white/10 rounded text-white"
                  />
                  <button
                    onClick={() => {
                      if (newFactoryAddress && /^0x[a-fA-F0-9]{40}$/.test(newFactoryAddress)) {
                        addFactory(newFactoryAddress as `0x${string}`)
                        setNewFactoryAddress('')
                      }
                    }}
                    disabled={
                      !newFactoryAddress ||
                      !/^0x[a-fA-F0-9]{40}$/.test(newFactoryAddress) ||
                      isVestingPending ||
                      isVestingConfirming
                    }
                    className={`px-4 py-2 rounded ${
                      newFactoryAddress &&
                      /^0x[a-fA-F0-9]{40}$/.test(newFactoryAddress) &&
                      !isVestingPending &&
                      !isVestingConfirming
                        ? 'bg-blue-600 hover:bg-blue-700'
                        : 'bg-gray-700 text-gray-400 cursor-not-allowed'
                    } text-white`}
                  >
                    Add Factory
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Contract addresses */}
        <div className="rounded-2xl p-4 bg-gray-900 border border-gray-800 text-xs text-gray-400">
          <div>
            SUMMER: <span className="font-mono text-blue-300">{summerAddress}</span>
          </div>
          <div>
            xSUMR: <span className="font-mono text-blue-300">{xSummerAddress}</span>
          </div>
          <div>
            Staking: <span className="font-mono text-blue-300">{stakingAddress}</span>
          </div>
          {escrowAddress && (
            <div>
              Escrow: <span className="font-mono text-blue-300">{escrowAddress}</span>
            </div>
          )}
          {factoryV2Address && (
            <div>
              Factory V2: <span className="font-mono text-blue-300">{factoryV2Address}</span>
            </div>
          )}
        </div>
      </div>
    </main>
  )
}
