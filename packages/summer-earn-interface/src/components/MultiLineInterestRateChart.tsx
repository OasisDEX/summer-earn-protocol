'use client'

import { useMemo } from 'react'
import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'

import {
  useDailyInterestRates,
  useHourlyInterestRates,
  useInterestRates,
  useProducts,
} from '../hooks/useInterestRates'
import { ChainId } from '../types'

type TimeInterval = '10min' | 'hourly' | 'daily'

// Curated palette for chart lines — visually distinct on dark backgrounds
const LINE_COLORS = [
  '#89acff', // primary blue
  '#68fadd', // secondary teal
  '#bfd8e5', // tertiary ice
  '#ff716c', // error coral
  '#c084fc', // violet
  '#fbbf24', // amber
  '#34d399', // emerald
  '#f472b6', // pink
  '#60a5fa', // sky
  '#a78bfa', // purple
  '#fb923c', // orange
  '#2dd4bf', // teal
]

// Predefined MA period options
export const MA_PERIODS = [7, 14, 21, 50] as const
export type MAPeriod = (typeof MA_PERIODS)[number]

export interface MAConfig {
  sma: MAPeriod[]
  ema: MAPeriod[]
}

// ─── Moving Average Calculations ─────────────────────────────────────────

/** Compute Simple Moving Average for a series of values */
function computeSMA(values: (number | undefined)[], period: number): (number | undefined)[] {
  const result: (number | undefined)[] = []
  for (let i = 0; i < values.length; i++) {
    if (i < period - 1) {
      result.push(undefined)
      continue
    }
    let sum = 0
    let count = 0
    for (let j = i - period + 1; j <= i; j++) {
      if (values[j] !== undefined) {
        sum += values[j]!
        count++
      }
    }
    result.push(count > 0 ? sum / count : undefined)
  }
  return result
}

/** Compute Exponential Moving Average for a series of values */
function computeEMA(values: (number | undefined)[], period: number): (number | undefined)[] {
  const result: (number | undefined)[] = []
  const k = 2 / (period + 1)
  let prevEma: number | undefined

  for (let i = 0; i < values.length; i++) {
    const val = values[i]
    if (val === undefined) {
      result.push(prevEma)
      continue
    }
    if (prevEma === undefined) {
      // Use first valid value as the seed
      prevEma = val
      result.push(val)
    } else {
      const ema = val * k + prevEma * (1 - k)
      prevEma = ema
      result.push(ema)
    }
  }
  return result
}

// ─── Component ───────────────────────────────────────────────────────────

interface MultiLineInterestRateChartProps {
  chainId: ChainId
  productIds: string[]
  fromTimestamp: number
  interval: TimeInterval
  maConfig?: MAConfig
}

/** Hook that fetches interest rate data for a single product and normalises it */
function useProductChartData(
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
  interval: TimeInterval,
  enabled: boolean,
) {
  const { data: rawRates } = useInterestRates(
    chainId,
    enabled && interval === '10min' ? productId : '',
    fromTimestamp,
  )
  const { data: hourlyRates } = useHourlyInterestRates(
    chainId,
    enabled && interval === 'hourly' ? productId : '',
    fromTimestamp,
  )
  const { data: dailyRates } = useDailyInterestRates(
    chainId,
    enabled && interval === 'daily' ? productId : '',
    fromTimestamp,
  )

  return useMemo(() => {
    if (interval === '10min' && rawRates) {
      return rawRates.map((r) => ({
        ts: Number(r.timestamp),
        rate: Number(r.rate),
      }))
    }
    if (interval === 'hourly' && hourlyRates) {
      return hourlyRates.map((r) => ({
        ts: Number(r.date),
        rate: Number(r.averageRate),
      }))
    }
    if (interval === 'daily' && dailyRates) {
      return dailyRates.map((r) => ({
        ts: Number(r.date),
        rate: Number(r.averageRate),
      }))
    }
    return []
  }, [interval, rawRates, hourlyRates, dailyRates])
}

export const MultiLineInterestRateChart = ({
  chainId,
  productIds,
  fromTimestamp,
  interval,
  maConfig,
}: MultiLineInterestRateChartProps) => {
  const { data: products } = useProducts(chainId)

  // Fetch data for each selected product (up to 12)
  const ids = productIds.slice(0, 12)

  const d0 = useProductChartData(chainId, ids[0] ?? '', fromTimestamp, interval, !!ids[0])
  const d1 = useProductChartData(chainId, ids[1] ?? '', fromTimestamp, interval, !!ids[1])
  const d2 = useProductChartData(chainId, ids[2] ?? '', fromTimestamp, interval, !!ids[2])
  const d3 = useProductChartData(chainId, ids[3] ?? '', fromTimestamp, interval, !!ids[3])
  const d4 = useProductChartData(chainId, ids[4] ?? '', fromTimestamp, interval, !!ids[4])
  const d5 = useProductChartData(chainId, ids[5] ?? '', fromTimestamp, interval, !!ids[5])
  const d6 = useProductChartData(chainId, ids[6] ?? '', fromTimestamp, interval, !!ids[6])
  const d7 = useProductChartData(chainId, ids[7] ?? '', fromTimestamp, interval, !!ids[7])
  const d8 = useProductChartData(chainId, ids[8] ?? '', fromTimestamp, interval, !!ids[8])
  const d9 = useProductChartData(chainId, ids[9] ?? '', fromTimestamp, interval, !!ids[9])
  const d10 = useProductChartData(chainId, ids[10] ?? '', fromTimestamp, interval, !!ids[10])
  const d11 = useProductChartData(chainId, ids[11] ?? '', fromTimestamp, interval, !!ids[11])

  const allData = [d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11]

  const smaPeriods = maConfig?.sma ?? []
  const emaPeriods = maConfig?.ema ?? []

  // Build product name lookup
  const productNames = useMemo(() => {
    const map: Record<string, string> = {}
    products?.forEach((p) => {
      map[p.id] = `${p.name} (${p.token.symbol})`
    })
    return map
  }, [products])

  // Merge all product data into a single array keyed by timestamp
  // and compute MA columns
  const mergedData = useMemo(() => {
    const tsMap = new Map<number, Record<string, number | string | undefined>>()

    ids.forEach((id, idx) => {
      const points = allData[idx] ?? []
      points.forEach((pt) => {
        if (!tsMap.has(pt.ts)) {
          tsMap.set(pt.ts, { ts: pt.ts })
        }
        tsMap.get(pt.ts)![id] = pt.rate
      })
    })

    const sorted = Array.from(tsMap.values()).sort((a, b) => (a.ts as number) - (b.ts as number))

    // Compute MAs per product
    if (smaPeriods.length > 0 || emaPeriods.length > 0) {
      ids.forEach((id) => {
        const rawValues = sorted.map((row) => row[id] as number | undefined)

        smaPeriods.forEach((period) => {
          const smaValues = computeSMA(rawValues, period)
          smaValues.forEach((val, i) => {
            sorted[i][`${id}__sma${period}`] = val
          })
        })

        emaPeriods.forEach((period) => {
          const emaValues = computeEMA(rawValues, period)
          emaValues.forEach((val, i) => {
            sorted[i][`${id}__ema${period}`] = val
          })
        })
      })
    }

    return sorted
  }, [ids, allData, smaPeriods, emaPeriods])

  // Build a human-friendly label lookup for all keys (including MA keys)
  const allKeyLabels = useMemo(() => {
    const labels: Record<string, string> = {}
    ids.forEach((id) => {
      const pName = productNames[id] ?? id
      labels[id] = pName
      smaPeriods.forEach((p) => {
        labels[`${id}__sma${p}`] = `${pName} SMA-${p}`
      })
      emaPeriods.forEach((p) => {
        labels[`${id}__ema${p}`] = `${pName} EMA-${p}`
      })
    })
    return labels
  }, [ids, productNames, smaPeriods, emaPeriods])

  // Format timestamp for X axis
  const formatDate = (ts: number) => {
    const d = new Date(ts * 1000)
    if (interval === '10min')
      return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    if (interval === 'hourly')
      return d.toLocaleDateString([], { month: 'short', day: 'numeric', hour: '2-digit' })
    return d.toLocaleDateString([], { month: 'short', day: 'numeric' })
  }

  if (ids.length === 0) {
    return (
      <div className="w-full h-[420px] flex items-center justify-center text-[#757578]">
        <div className="text-center space-y-2">
          <svg
            className="w-12 h-12 mx-auto text-[#47484a]"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"
            />
          </svg>
          <p className="text-sm font-medium">Select products to compare</p>
          <p className="text-xs text-[#47484a]">Use the dropdown above to add protocols</p>
        </div>
      </div>
    )
  }

  if (mergedData.length === 0) {
    return (
      <div className="w-full h-[420px] flex items-center justify-center">
        <div className="flex items-center gap-3 text-[#757578]">
          <div className="w-5 h-5 border-2 border-[#89acff] border-t-transparent rounded-full animate-spin" />
          <span className="text-sm font-medium">Loading rate data…</span>
        </div>
      </div>
    )
  }

  return (
    <div className="w-full h-[420px]">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={mergedData} margin={{ top: 8, right: 12, bottom: 0, left: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
          <XAxis
            dataKey="ts"
            tickFormatter={formatDate}
            stroke="#47484a"
            tick={{ fill: '#757578', fontSize: 11, fontWeight: 600 }}
            tickLine={false}
            axisLine={{ stroke: 'rgba(255,255,255,0.08)' }}
          />
          <YAxis
            tickFormatter={(v) => `${Number(v).toFixed(1)}%`}
            domain={['auto', 'auto']}
            stroke="#47484a"
            tick={{ fill: '#757578', fontSize: 11, fontWeight: 600 }}
            tickLine={false}
            axisLine={false}
            width={52}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: 'rgba(24, 26, 28, 0.95)',
              border: '1px solid rgba(255,255,255,0.1)',
              borderRadius: '12px',
              backdropFilter: 'blur(24px)',
              color: '#fdfbfe',
              boxShadow: '0 25px 50px rgba(0,0,0,0.5)',
              padding: '12px 16px',
            }}
            labelFormatter={(ts) => {
              const d = new Date(Number(ts) * 1000)
              return d.toLocaleDateString([], {
                weekday: 'short',
                month: 'short',
                day: 'numeric',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
              })
            }}
            formatter={(value: number, name: string) => [
              value !== undefined ? `${Number(value).toFixed(4)}%` : '—',
              allKeyLabels[name] ?? name,
            ]}
            cursor={{ stroke: 'rgba(137,172,255,0.2)', strokeWidth: 1 }}
          />
          <Legend
            verticalAlign="top"
            height={36}
            formatter={(value: string) => (
              <span
                style={{
                  color: '#ababad',
                  fontSize: '11px',
                  fontWeight: 600,
                  letterSpacing: '0.05em',
                }}
              >
                {allKeyLabels[value] ?? value}
              </span>
            )}
          />
          {/* Raw rate lines */}
          {ids.map((id, idx) => (
            <Line
              key={id}
              type="monotone"
              dataKey={id}
              stroke={LINE_COLORS[idx % LINE_COLORS.length]}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4, strokeWidth: 2 }}
              connectNulls
              name={id}
            />
          ))}
          {/* SMA overlay lines — dashed */}
          {ids.map((id, idx) =>
            smaPeriods.map((period) => (
              <Line
                key={`${id}__sma${period}`}
                type="monotone"
                dataKey={`${id}__sma${period}`}
                stroke={LINE_COLORS[idx % LINE_COLORS.length]}
                strokeWidth={1.5}
                strokeDasharray="6 3"
                strokeOpacity={0.6}
                dot={false}
                activeDot={false}
                connectNulls
                name={`${id}__sma${period}`}
              />
            )),
          )}
          {/* EMA overlay lines — dotted */}
          {ids.map((id, idx) =>
            emaPeriods.map((period) => (
              <Line
                key={`${id}__ema${period}`}
                type="monotone"
                dataKey={`${id}__ema${period}`}
                stroke={LINE_COLORS[idx % LINE_COLORS.length]}
                strokeWidth={1.5}
                strokeDasharray="2 3"
                strokeOpacity={0.6}
                dot={false}
                activeDot={false}
                connectNulls
                name={`${id}__ema${period}`}
              />
            )),
          )}
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
