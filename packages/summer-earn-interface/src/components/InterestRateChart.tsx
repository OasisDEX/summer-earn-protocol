import { useMemo } from 'react'
import {
  CartesianGrid,
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
} from '../hooks/useInterestRates'
import { ChainId } from '../types'

type TimeInterval = '10min' | 'hourly' | 'daily'

interface InterestRateChartProps {
  chainId: ChainId
  productId: string
  fromTimestamp: number
  interval: TimeInterval
}

export const InterestRateChart = ({
  chainId,
  productId,
  fromTimestamp,
  interval,
}: InterestRateChartProps) => {
  const { data: interestRates, isLoading: isLoadingInterestRates } = useInterestRates(
    chainId,
    productId,
    fromTimestamp,
  )
  const { data: hourlyRates, isLoading: isLoadingHourlyRates } = useHourlyInterestRates(
    chainId,
    productId,
    fromTimestamp,
  )
  const { data: dailyRates, isLoading: isLoadingDailyRates } = useDailyInterestRates(
    chainId,
    productId,
    fromTimestamp,
  )

  const isLoading = isLoadingInterestRates || isLoadingHourlyRates || isLoadingDailyRates

  const chartData = useMemo(() => {
    if (interval === '10min' && interestRates) {
      return interestRates.map((rate) => ({
        date: new Date(Number(rate.timestamp) * 1000).toLocaleString(),
        rate: Number(rate.rate),
      }))
    }
    if (interval === 'hourly' && hourlyRates) {
      return hourlyRates.map((rate) => ({
        date: new Date(Number(rate.date) * 1000).toLocaleString(),
        rate: Number(rate.averageRate),
      }))
    }
    if (interval === 'daily' && dailyRates) {
      return dailyRates.map((rate) => ({
        date: new Date(Number(rate.date) * 1000).toLocaleDateString(),
        rate: Number(rate.averageRate),
      }))
    }
    return []
  }, [interval, interestRates, hourlyRates, dailyRates])

  if (isLoading) {
    return <div>Loading...</div>
  }

  if (!chartData.length) {
    return <div>No data available</div>
  }

  return (
    <div className="w-full h-[400px]">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis dataKey="date" stroke="#111827" tick={{ fill: '#111827' }} />
          <YAxis
            tickFormatter={(value) => `${value.toFixed(2)}%`}
            domain={['auto', 'auto']}
            stroke="#111827"
            tick={{ fill: '#111827' }}
          />
          <Tooltip
            formatter={(value: number) => [`${value.toFixed(2)}%`, 'Rate']}
            labelFormatter={(label) => `Date: ${label}`}
            contentStyle={{
              backgroundColor: '#ffffff',
              border: '1px solid #e5e7eb',
              borderRadius: '0.375rem',
              color: '#111827',
            }}
            labelStyle={{ color: '#111827' }}
          />
          <Line
            type="monotone"
            dataKey="rate"
            stroke="#2563eb"
            strokeWidth={2}
            dot={false}
            name="Interest Rate"
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
