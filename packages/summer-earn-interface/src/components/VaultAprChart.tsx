'use client'

import { useMemo, useState } from 'react'
import {
  Brush,
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'

interface RateDataPoint {
  timestamp: number
  date: string
  weekly?: number
  daily?: number
  hourly?: number
}

interface VaultAprChartProps {
  weeklyRates: Array<{ date: string; averageRate: string }>
  dailyRates: Array<{ date: string; averageRate: string }>
  hourlyRates: Array<{ date: string; averageRate: string }>
  vaultName: string
}

export const VaultAprChart = ({ weeklyRates, dailyRates, hourlyRates }: VaultAprChartProps) => {
  const [showWeekly, setShowWeekly] = useState(true)
  const [showDaily, setShowDaily] = useState(true)
  const [showHourly, setShowHourly] = useState(true)

  // Calculate averages
  const averages = useMemo(() => {
    // 1 day average: last 24 hourly rates
    const last24Hourly = hourlyRates.slice(0, 24)
    const avg1Day =
      last24Hourly.length > 0
        ? last24Hourly.reduce((sum, rate) => sum + Number(rate.averageRate), 0) /
          last24Hourly.length
        : null

    // 7 day average: last 7 daily rates
    const last7Daily = dailyRates.slice(0, 7)
    const avg7Day =
      last7Daily.length > 0
        ? last7Daily.reduce((sum, rate) => sum + Number(rate.averageRate), 0) / last7Daily.length
        : null

    // 30 day average: last 30 daily rates
    const last30Daily = dailyRates.slice(0, 30)
    const avg30Day =
      last30Daily.length > 0
        ? last30Daily.reduce((sum, rate) => sum + Number(rate.averageRate), 0) / last30Daily.length
        : null

    return { avg1Day, avg7Day, avg30Day }
  }, [hourlyRates, dailyRates])

  const chartData = useMemo(() => {
    // Create a map to combine all rates by timestamp
    const dataMap = new Map<number, RateDataPoint>()

    // Process weekly rates
    weeklyRates.forEach((rate) => {
      const timestamp = Number(rate.date) * 1000
      const existing = dataMap.get(timestamp) || {
        timestamp,
        date: new Date(timestamp).toISOString(),
      }
      existing.weekly = Number(rate.averageRate)
      dataMap.set(timestamp, existing)
    })

    // Process daily rates
    dailyRates.forEach((rate) => {
      const timestamp = Number(rate.date) * 1000
      const existing = dataMap.get(timestamp) || {
        timestamp,
        date: new Date(timestamp).toISOString(),
      }
      existing.daily = Number(rate.averageRate)
      dataMap.set(timestamp, existing)
    })

    // Process hourly rates
    hourlyRates.forEach((rate) => {
      const timestamp = Number(rate.date) * 1000
      const existing = dataMap.get(timestamp) || {
        timestamp,
        date: new Date(timestamp).toISOString(),
      }
      existing.hourly = Number(rate.averageRate)
      dataMap.set(timestamp, existing)
    })

    // Convert to array and sort by timestamp
    return Array.from(dataMap.values())
      .sort((a, b) => a.timestamp - b.timestamp)
      .map((point) => ({
        ...point,
        date: new Date(point.timestamp).toLocaleString('en-US', {
          month: 'short',
          day: 'numeric',
          hour: 'numeric',
          minute: '2-digit',
        }),
      }))
  }, [weeklyRates, dailyRates, hourlyRates])

  if (chartData.length === 0) {
    return (
      <div className="flex items-center justify-center h-[400px] text-gray-500">
        No rate data available
      </div>
    )
  }

  return (
    <div className="w-full space-y-4">
      {/* Average Stats */}
      {(averages.avg1Day !== null || averages.avg7Day !== null || averages.avg30Day !== null) && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
          {averages.avg1Day !== null && (
            <div className="bg-gray-800 rounded-lg border border-gray-700 p-3">
              <div className="text-xs text-gray-400 mb-1">1 Day Average</div>
              <div className="text-lg font-semibold text-green-400">
                {averages.avg1Day.toFixed(4)}%
              </div>
            </div>
          )}
          {averages.avg7Day !== null && (
            <div className="bg-gray-800 rounded-lg border border-gray-700 p-3">
              <div className="text-xs text-gray-400 mb-1">7 Day Average</div>
              <div className="text-lg font-semibold text-blue-400">
                {averages.avg7Day.toFixed(4)}%
              </div>
            </div>
          )}
          {averages.avg30Day !== null && (
            <div className="bg-gray-800 rounded-lg border border-gray-700 p-3">
              <div className="text-xs text-gray-400 mb-1">30 Day Average</div>
              <div className="text-lg font-semibold text-purple-400">
                {averages.avg30Day.toFixed(4)}%
              </div>
            </div>
          )}
        </div>
      )}

      {/* Legend/Toggle Controls */}
      <div className="flex flex-wrap gap-4 text-sm">
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={showWeekly}
            onChange={(e) => setShowWeekly(e.target.checked)}
            className="w-4 h-4 rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500"
          />
          <span className="text-white">Weekly</span>
          <div className="w-3 h-3 rounded-full bg-purple-500" />
        </label>
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={showDaily}
            onChange={(e) => setShowDaily(e.target.checked)}
            className="w-4 h-4 rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500"
          />
          <span className="text-white">Daily</span>
          <div className="w-3 h-3 rounded-full bg-blue-500" />
        </label>
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={showHourly}
            onChange={(e) => setShowHourly(e.target.checked)}
            className="w-4 h-4 rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500"
          />
          <span className="text-white">Hourly</span>
          <div className="w-3 h-3 rounded-full bg-green-500" />
        </label>
      </div>

      {/* Chart */}
      <div className="w-full h-[500px]">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 60 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#374151" opacity={0.3} />
            <XAxis
              dataKey="date"
              stroke="#9ca3af"
              tick={{ fill: '#9ca3af', fontSize: 12 }}
              angle={-45}
              textAnchor="end"
              height={80}
              interval="preserveStartEnd"
            />
            <YAxis
              stroke="#9ca3af"
              tick={{ fill: '#9ca3af', fontSize: 12 }}
              tickFormatter={(value) => `${value.toFixed(2)}%`}
              domain={['auto', 'auto']}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: '#1f2937',
                border: '1px solid #374151',
                borderRadius: '0.5rem',
                color: '#f3f4f6',
              }}
              labelStyle={{ color: '#9ca3af', marginBottom: '0.5rem' }}
              formatter={(value: number, name: string) => [
                `${value.toFixed(4)}%`,
                name.charAt(0).toUpperCase() + name.slice(1),
              ]}
              labelFormatter={(label) => `Date: ${label}`}
            />
            <Legend
              wrapperStyle={{ paddingTop: '1rem' }}
              iconType="line"
              formatter={(value) => <span style={{ color: '#9ca3af' }}>{value}</span>}
            />
            {showWeekly && (
              <Line
                type="monotone"
                dataKey="weekly"
                stroke="#a855f7"
                strokeWidth={2}
                dot={false}
                name="Weekly"
                connectNulls
              />
            )}
            {showDaily && (
              <Line
                type="monotone"
                dataKey="daily"
                stroke="#3b82f6"
                strokeWidth={2}
                dot={false}
                name="Daily"
                connectNulls
              />
            )}
            {showHourly && (
              <Line
                type="monotone"
                dataKey="hourly"
                stroke="#10b981"
                strokeWidth={2}
                dot={false}
                name="Hourly"
                connectNulls
              />
            )}
            {/* Average reference lines */}
            {averages.avg1Day !== null && (
              <ReferenceLine
                y={averages.avg1Day}
                stroke="#10b981"
                strokeWidth={1.5}
                strokeDasharray="5 5"
                label={{
                  value: '1d Avg',
                  position: 'right',
                  fill: '#10b981',
                  fontSize: 12,
                }}
              />
            )}
            {averages.avg7Day !== null && (
              <ReferenceLine
                y={averages.avg7Day}
                stroke="#3b82f6"
                strokeWidth={1.5}
                strokeDasharray="5 5"
                label={{
                  value: '7d Avg',
                  position: 'right',
                  fill: '#3b82f6',
                  fontSize: 12,
                }}
              />
            )}
            {averages.avg30Day !== null && (
              <ReferenceLine
                y={averages.avg30Day}
                stroke="#a855f7"
                strokeWidth={1.5}
                strokeDasharray="5 5"
                label={{
                  value: '30d Avg',
                  position: 'right',
                  fill: '#a855f7',
                  fontSize: 12,
                }}
              />
            )}
            <Brush
              dataKey="date"
              height={30}
              stroke="#4b5563"
              fill="#1f2937"
              tickFormatter={(value) => {
                const date = chartData.find((d) => d.date === value)
                return date ? new Date(date.timestamp).toLocaleDateString() : value
              }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
