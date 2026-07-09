'use client'

import { useCallback, useMemo, useState } from 'react'
import { useAccount, useSwitchChain } from 'wagmi'

import {
  MA_PERIODS,
  type MAConfig,
  type MAPeriod,
  MultiLineInterestRateChart,
} from '../../components/MultiLineInterestRateChart'
import { MultiSelectDropdown } from '../../components/MultiSelectDropdown'
import {
  getFromTimestampForRange,
  RangeOption,
  RangeSelector,
} from '../../components/RangeSelector'
import { PageHeader } from '../../components/ui'
import { CHAIN_NAMES } from '../../config/chains'
import { useProducts } from '../../hooks/useInterestRates'
import { useLocalStorage } from '../../hooks/useLocalStorage'
import { useSyncWalletChain } from '../../hooks/useSyncWalletChain'
import { ChainId } from '../../types'

type TimeInterval = '10min' | 'hourly' | 'daily'

/** Toggle a period in/out of a set */
function togglePeriod(current: MAPeriod[], period: MAPeriod): MAPeriod[] {
  return current.includes(period) ? current.filter((p) => p !== period) : [...current, period]
}

export default function InterestRatesPage() {
  const { chain } = useAccount()
  const { switchChain } = useSwitchChain()
  const [selectedProductIds, setSelectedProductIds] = useState<string[]>([])
  const [selectedInterval, setSelectedInterval] = useState<TimeInterval>('hourly')
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>(
    'selectedChain',
    (chain?.id.toString() as ChainId) ?? '1',
  )

  const [range, setRange] = useState<RangeOption>('30d')
  const fromTimestamp = useMemo(() => getFromTimestampForRange(range), [range])

  // MA state
  const [smaPeriods, setSmaPeriods] = useState<MAPeriod[]>([])
  const [emaPeriods, setEmaPeriods] = useState<MAPeriod[]>([])

  const maConfig = useMemo<MAConfig>(
    () => ({ sma: smaPeriods, ema: emaPeriods }),
    [smaPeriods, emaPeriods],
  )

  const toggleSma = useCallback((p: MAPeriod) => setSmaPeriods((cur) => togglePeriod(cur, p)), [])
  const toggleEma = useCallback((p: MAPeriod) => setEmaPeriods((cur) => togglePeriod(cur, p)), [])

  const currentChainId = storedChain
  useSyncWalletChain(currentChainId)
  const { data: products, isLoading: isLoadingProducts } = useProducts(currentChainId)

  const productOptions = useMemo(
    () =>
      (products ?? []).map((p) => ({
        id: p.id,
        label: `${p.name} (${p.token.symbol})`,
      })),
    [products],
  )

  const handleChainChange = async (chainId: ChainId) => {
    try {
      await switchChain({ chainId: Number(chainId) })
      setStoredChain(chainId)
      setSelectedProductIds([])
    } catch (error) {
      console.error('Failed to switch chain:', error)
    }
  }

  if (!chain) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="w-16 h-16 mx-auto rounded-2xl bg-surface-container-high flex items-center justify-center border border-white/[0.06]">
            <svg
              className="w-8 h-8 text-primary"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={1.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M21 12a2.25 2.25 0 00-2.25-2.25H15a3 3 0 11-6 0H5.25A2.25 2.25 0 003 12m18 0v6a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 18v-6m18 0V9M3 12V9m18 0a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 9m18 0V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v3"
              />
            </svg>
          </div>
          <p className="text-on-surface font-bold font-headline text-lg">Connect your wallet</p>
          <p className="text-outline text-sm">Please connect your wallet to view interest rates</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen text-on-surface selection:bg-primary selection:text-on-primary">
      <div className="max-w-7xl mx-auto px-6 py-10 space-y-8">
        {/* Header & Controls */}
        <PageHeader
          title="Yield Analysis"
          description="Compare historical and real-time interest rates across DeFi protocols."
          actions={
            <div className="flex flex-wrap items-end gap-4">
              {/* Chain Selector */}
              <div className="flex flex-col gap-1.5">
                <label className="text-[11px] uppercase tracking-wider font-bold text-on-surface-variant px-1">
                  Network
                </label>
                <select
                  className="px-4 py-2.5 rounded-lg bg-surface-container-high border border-white/[0.06]
                  text-sm font-medium text-on-surface hover:bg-surface-bright transition-colors
                  cursor-pointer appearance-none pr-8
                  focus:outline-none focus:ring-1 focus:ring-primary/40"
                  style={{
                    backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%23ababad' stroke-width='2'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' d='M19 9l-7 7-7-7'/%3E%3C/svg%3E")`,
                    backgroundRepeat: 'no-repeat',
                    backgroundPosition: 'right 0.5rem center',
                    backgroundSize: '1rem',
                  }}
                  value={currentChainId}
                  onChange={(e) => handleChainChange(e.target.value as ChainId)}
                >
                  {Object.entries(CHAIN_NAMES).map(([id, name]) => (
                    <option key={id} value={id}>
                      {name}
                    </option>
                  ))}
                </select>
              </div>

              {/* Interval Selector */}
              <div className="flex flex-col gap-1.5">
                <label className="text-[11px] uppercase tracking-wider font-bold text-on-surface-variant px-1">
                  Interval
                </label>
                <select
                  className="px-4 py-2.5 rounded-lg bg-surface-container-high border border-white/[0.06]
                  text-sm font-medium text-on-surface hover:bg-surface-bright transition-colors
                  cursor-pointer appearance-none pr-8
                  focus:outline-none focus:ring-1 focus:ring-primary/40"
                  style={{
                    backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%23ababad' stroke-width='2'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' d='M19 9l-7 7-7-7'/%3E%3C/svg%3E")`,
                    backgroundRepeat: 'no-repeat',
                    backgroundPosition: 'right 0.5rem center',
                    backgroundSize: '1rem',
                  }}
                  value={selectedInterval}
                  onChange={(e) => setSelectedInterval(e.target.value as TimeInterval)}
                >
                  <option value="10min">10 min</option>
                  <option value="hourly">Hourly</option>
                  <option value="daily">Daily</option>
                </select>
              </div>

              {/* Period Selector */}
              <div className="flex flex-col gap-1.5">
                <label className="text-[11px] uppercase tracking-wider font-bold text-on-surface-variant px-1">
                  Period
                </label>
                <RangeSelector value={range} onChange={setRange} />
              </div>
            </div>
          }
        />

        {/* Product Multi-Select + MA toggles row */}
        <div className="flex flex-col lg:flex-row gap-6 items-start">
          {/* Product Multi-Select */}
          <div className="flex flex-col gap-1.5 flex-1 max-w-xl">
            <label className="text-[11px] uppercase tracking-wider font-bold text-on-surface-variant px-1">
              Protocols
            </label>
            {isLoadingProducts ? (
              <div className="h-[42px] rounded-lg bg-surface-container-high border border-white/[0.06] animate-pulse" />
            ) : (
              <MultiSelectDropdown
                options={productOptions}
                selected={selectedProductIds}
                onChange={setSelectedProductIds}
                placeholder="Search and select protocols…"
              />
            )}
          </div>

          {/* SMA Toggles */}
          <div className="flex flex-col gap-1.5">
            <label className="text-[11px] uppercase tracking-wider font-bold text-on-surface-variant px-1">
              SMA
              <span className="ml-1 normal-case tracking-normal font-normal text-outline">
                (dashed)
              </span>
            </label>
            <div className="flex bg-surface-container-low p-1 rounded-lg border border-white/[0.06]">
              {MA_PERIODS.map((p) => (
                <button
                  key={`sma-${p}`}
                  type="button"
                  onClick={() => toggleSma(p)}
                  className={`px-3 py-1.5 text-xs font-semibold rounded-md transition-all ${
                    smaPeriods.includes(p)
                      ? 'bg-secondary text-on-secondary shadow-lg shadow-secondary/20'
                      : 'text-on-surface-variant hover:text-on-surface hover:bg-white/[0.04]'
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>

          {/* EMA Toggles */}
          <div className="flex flex-col gap-1.5">
            <label className="text-[11px] uppercase tracking-wider font-bold text-on-surface-variant px-1">
              EMA
              <span className="ml-1 normal-case tracking-normal font-normal text-outline">
                (dotted)
              </span>
            </label>
            <div className="flex bg-surface-container-low p-1 rounded-lg border border-white/[0.06]">
              {MA_PERIODS.map((p) => (
                <button
                  key={`ema-${p}`}
                  type="button"
                  onClick={() => toggleEma(p)}
                  className={`px-3 py-1.5 text-xs font-semibold rounded-md transition-all ${
                    emaPeriods.includes(p)
                      ? 'bg-violet-400 text-on-primary shadow-lg shadow-violet-400/20'
                      : 'text-on-surface-variant hover:text-on-surface hover:bg-white/[0.04]'
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Main Chart */}
        <div className="bg-surface-container-low rounded-xl p-6 border border-white/[0.04] shadow-sm overflow-hidden">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="font-headline font-bold text-lg">Interest Rate Trend</h3>
              <p className="text-xs text-on-surface-variant">
                {selectedProductIds.length > 0
                  ? `Comparing ${selectedProductIds.length} protocol${selectedProductIds.length > 1 ? 's' : ''}` +
                    (smaPeriods.length > 0 || emaPeriods.length > 0
                      ? ` · MA overlays: ${[...smaPeriods.map((p) => `SMA-${p}`), ...emaPeriods.map((p) => `EMA-${p}`)].join(', ')}`
                      : '')
                  : 'Select protocols above to compare rates'}
              </p>
            </div>
          </div>

          <MultiLineInterestRateChart
            chainId={currentChainId}
            productIds={selectedProductIds}
            fromTimestamp={fromTimestamp}
            interval={selectedInterval}
            maConfig={maConfig}
          />
        </div>
      </div>
    </div>
  )
}
