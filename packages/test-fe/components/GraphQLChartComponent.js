import React, { useState, useEffect } from 'react'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  Scatter,
  ResponsiveContainer,
} from 'recharts'
import { motion } from 'framer-motion'

const GraphQLChartComponent = () => {
  const [data, setData] = useState(null)
  const [showAPR, setShowAPR] = useState(true)
  const [hoveredArk, setHoveredArk] = useState(null)

  const arkNames = ['MetaMorphoArk', 'CompoundV3Ark', 'AaveV3Ark', 'MorphoArk', 'Buffer Ark']

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('/api/graphql', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: `
              {
                vaults {
                  hourlySnapshots {
                    timestamp
                    apr
                    totalValueLockedUSD
                    inputTokenBalance
                    outputTokenSupply
                  }
                  arks {
                    hourlySnapshots {
                      timestamp
                      apr
                      totalValueLockedUSD
                    }
                    rebalancesFrom {
                      to {
                        id
                      }
                      timestamp
                      amount
                      amountUSD
                    }
                    rebalancesTo {
                      from {
                        id
                      }
                      timestamp
                      amount
                      amountUSD
                    }
                  }
                }
              }
            `,
          }),
        })
        const result = await response.json()
        setData(result.data)
      } catch (error) {
        console.error('Error fetching data:', error)
      }
    }

    fetchData()
  }, [])

  if (!data)
    return (
      <div className="flex justify-center items-center h-screen">
        <div className="animate-spin rounded-full h-32 w-32 border-t-2 border-b-2 border-purple-500"></div>
      </div>
    )

  const vault = data.vaults[0]
  const arks = vault.arks

  const roundToTwoDecimals = (num) => Math.round(num * 100) / 100
  const roundToSixDecimals = (num) => Math.round(num * 1000000) / 1000000

  const chartData = vault.hourlySnapshots.map((snapshot) => ({
    timestamp: new Date(snapshot.timestamp * 1000).toLocaleString(),
    vaultTVL: roundToSixDecimals(parseFloat(snapshot.totalValueLockedUSD)),
    vaultAPR: roundToTwoDecimals(parseFloat(snapshot.apr)),
    inputTokenBalance: roundToSixDecimals(parseFloat(snapshot.inputTokenBalance)),
    outputTokenSupply: roundToSixDecimals(parseFloat(snapshot.outputTokenSupply)),
    ...arks.reduce((acc, ark, index) => {
      const arkSnapshot = ark.hourlySnapshots.find((s) => s.timestamp === snapshot.timestamp)
      if (arkSnapshot) {
        acc[`${arkNames[index]}TVL`] = roundToSixDecimals(
          parseFloat(arkSnapshot.totalValueLockedUSD),
        )
        acc[`${arkNames[index]}APR`] = roundToTwoDecimals(parseFloat(arkSnapshot.apr))
      }
      return acc
    }, {}),
  }))

  const rebalanceData = arks.flatMap((ark, fromIndex) => [
    ...ark.rebalancesFrom.map((rebalance) => ({
      timestamp: new Date(rebalance.timestamp * 1000).toLocaleString(),
      [`${arkNames[fromIndex]}To${arkNames[rebalance.to.id]}`]: roundToSixDecimals(
        parseFloat(rebalance.amountUSD),
      ),
    })),
    ...ark.rebalancesTo.map((rebalance) => ({
      timestamp: new Date(rebalance.timestamp * 1000).toLocaleString(),
      [`${arkNames[rebalance.from.id]}To${arkNames[fromIndex]}`]: roundToSixDecimals(
        parseFloat(rebalance.amountUSD),
      ),
    })),
  ])

  const allData = [...chartData, ...rebalanceData].sort(
    (a, b) => new Date(a.timestamp) - new Date(b.timestamp),
  )

  const colors = [
    '#FF6B6B',
    '#4ECDC4',
    '#45B7D1',
    '#FFA07A',
    '#98D8C8',
    '#F3A712',
    '#5EEAD4',
    '#FF9A8B',
    '#6A0572',
    '#AB83A1',
  ]

  const toggleView = () => {
    setShowAPR(!showAPR)
  }

  const CustomTooltip = ({ active, payload, label }) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-white p-4 rounded-lg shadow-lg border border-gray-200">
          <p className="text-gray-700">{`Timestamp: ${label}`}</p>
          {payload.map((entry, index) => (
            <p key={`item-${index}`} style={{ color: entry.color }}>
              {`${entry.name}: ${entry.value}`}
            </p>
          ))}
        </div>
      )
    }
    return null
  }

  return (
    <div className="p-8 bg-gray-100 min-h-screen">
      <h1 className="text-4xl font-bold mb-8 text-center text-gray-800">
        Vault Performance Dashboard
      </h1>
      <div className="mb-8 flex justify-center">
        <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={toggleView}
          className="px-6 py-3 bg-purple-600 text-white rounded-full shadow-lg font-semibold transition duration-300 ease-in-out transform hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-opacity-50"
        >
          {showAPR ? 'Show TVL' : 'Show APR'}
        </motion.button>
      </div>
      <div className="bg-white rounded-xl shadow-2xl p-6">
        <ResponsiveContainer width="100%" height={600}>
          <LineChart data={allData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="timestamp" stroke="#888" />
            <YAxis stroke="#888" />
            <Tooltip content={<CustomTooltip />} />
            <Legend
              verticalAlign="top"
              height={36}
              onMouseEnter={(e) => setHoveredArk(e.dataKey)}
              onMouseLeave={() => setHoveredArk(null)}
            />

            {showAPR ? (
              <>
                <Line
                  type="monotone"
                  dataKey="vaultAPR"
                  stroke={colors[0]}
                  name="Vault APR"
                  strokeWidth={hoveredArk === 'vaultAPR' ? 10 : 5}
                  dot={false}
                  animationDuration={1000}
                />
                {arkNames.map((arkName, index) => (
                  <Line
                    key={arkName}
                    type="monotone"
                    dataKey={`${arkName}APR`}
                    stroke={colors[index + 1]}
                    name={`${arkName} APR`}
                    strokeWidth={hoveredArk === `${arkName}APR` ? 4 : 2}
                    dot={false}
                    animationDuration={1000}
                  />
                ))}
              </>
            ) : (
              <>
                <Line
                  type="monotone"
                  dataKey="vaultTVL"
                  stroke={colors[0]}
                  name="Vault TVL"
                  strokeWidth={hoveredArk === 'vaultTVL' ? 4 : 2}
                  dot={false}
                  animationDuration={1000}
                />
                {arkNames.map((arkName, index) => (
                  <Line
                    key={arkName}
                    type="monotone"
                    dataKey={`${arkName}TVL`}
                    stroke={colors[index + 1]}
                    name={`${arkName} TVL`}
                    strokeWidth={hoveredArk === `${arkName}TVL` ? 4 : 2}
                    dot={false}
                    animationDuration={1000}
                  />
                ))}
                {arkNames.flatMap((fromArkName, fromIndex) =>
                  arkNames.map((toArkName, toIndex) => (
                    <Scatter
                      key={`${fromArkName}-${toArkName}`}
                      name={`Rebalance ${fromArkName} to ${toArkName}`}
                      dataKey={`${fromArkName}To${toArkName}`}
                      fill={colors[(fromIndex + toIndex) % colors.length]}
                      shape="star"
                    />
                  )),
                )}
              </>
            )}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}

export default GraphQLChartComponent
