import React, { useState, useEffect, useMemo } from 'react'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import { motion } from 'framer-motion'
import { AbiConstructorParamsNotFoundError } from 'viem'
import { availableMemory } from 'process'
const RebalanceArrow = ({ x, y, stroke, label }) => {
  return (
    <g transform={`translate(${x},${y})`}>
      <line
        x1="0"
        y1="0"
        x2="0"
        y2="-50"
        stroke={stroke}
        strokeWidth="2"
        markerEnd="url(#arrowhead)"
      />
      <text x="0" y="-25" dy="-5" fill={stroke} fontSize="10" textAnchor="middle">
        {label}
      </text>
    </g>
  )
}

const CustomizedDot = (props) => {
  const { cx, cy, payload, rebalances, colors, arkNames } = props

  const rebalance = rebalances.find(
    (r) => r.timestamp.getTime() === new Date(payload.timestamp).getTime(),
  )

  if (rebalance) {
    console.log('Rendering rebalance arrow:', rebalance)
    return (
      <RebalanceArrow
        x={cx}
        y={cy}
        stroke={
          colors[
            (arkNames.indexOf(rebalance.from) + arkNames.indexOf(rebalance.to)) % colors.length
          ]
        }
        label={`$${rebalance.amount}`}
      />
    )
  }

  return null
}

const GraphQLChartComponent = () => {
  const [data, setData] = useState(null)
  const [showAPR, setShowAPR] = useState(false)
  const [hoveredArk, setHoveredArk] = useState(null)
  // const [rebalances, setRebalances] = useState([]);

  const arkNames = ['MetaMorphoArk', 'CompoundV3Ark', 'AaveV3Ark', 'MorphoArk', 'Buffer Ark']
  const addressToArkName = new Map([
    ['0x926A20d893f14922084b4d32AEb41E3E1D4Ca905'.toLowerCase(), 'MorphoArk'],
    ['0x348015DBDB6353B553164f092ddd207bC05Bebac'.toLowerCase(), 'MetaMorphoArk'],
    ['0x6b790D0943cb5f33308C9Ad8A7284FE93F2cc2Fb'.toLowerCase(), 'CompoundV3Ark'],
    ['0x87E8277E6c17274d65448862d778aaCFB9a6ae8c'.toLowerCase(), 'AaveV3Ark'],
    ['0xdD8753eB847844062ff4fE935dc2113b6824458A'.toLowerCase(), 'Buffer Ark'],
  ])

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
    apr
    hourlySnapshots(orderBy: timestamp) {
      timestamp
      apr
      totalValueLockedUSD
      inputTokenBalance
      outputTokenSupply
    }
    actionSnapshots(orderBy: timestamp) {
      timestamp
      apr
      totalValueLockedUSD
      inputTokenBalance
      outputTokenSupply
    }
    arks {
      id
      apr
      hourlySnapshots(orderBy: timestamp) {
        timestamp
        apr
        aprLast1h
        totalValueLockedUSD
      }
      actionSnapshots(orderBy: timestamp) {
        timestamp
        apr
        totalValueLockedUSD
      }
      rebalancesFrom {
        to {
          id
        }
        from {
          id
        }
        timestamp
        amount
        amountUSD
      }
      rebalancesTo {
        to {
          id
        }
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

  const processedData = useMemo(() => {
    if (!data) return { chartData: [], rebalances: [] }

    const vault = data.vaults[0]
    const arks = vault.arks

    const roundToTwoDecimals = (num) => Math.round(num * 100) / 100
    const roundToSixDecimals = (num) => Math.round(num * 1000000) / 1000000
    const vaultSnapshots = vault.hourlySnapshots
      .concat(vault.actionSnapshots)
      .sort((a, b) => a.timestamp - b.timestamp)
    const chartData = vaultSnapshots.map((snapshot) => ({
      timestamp: new Date(snapshot.timestamp * 1000).toLocaleString(),
      vaultTVL: roundToSixDecimals(parseFloat(snapshot.totalValueLockedUSD)),
      vaultAPR: roundToTwoDecimals(parseFloat(snapshot.apr)),
      inputTokenBalance: roundToSixDecimals(parseFloat(snapshot.inputTokenBalance)),
      outputTokenSupply: roundToSixDecimals(parseFloat(snapshot.outputTokenSupply)),
      ...arks.reduce((acc, ark, index) => {
        const arkSnapshots = ark.hourlySnapshots
          .concat(ark.actionSnapshots)
          .sort((a, b) => a.timestamp - b.timestamp)
        const arkSnapshot = arkSnapshots.find((s) => s.timestamp === snapshot.timestamp)
        if (arkSnapshot) {
          acc[`${arkNames[index]}TVL`] = roundToSixDecimals(
            parseFloat(arkSnapshot.totalValueLockedUSD),
          )
          acc[`${arkNames[index]}APR`] = roundToTwoDecimals(parseFloat(arkSnapshot.apr))
        }
        return acc
      }, {}),
    }))
    const rebalances = arks.flatMap((ark, fromIndex) => [
      ...ark.rebalancesFrom.map((rebalance) => ({
        timestamp: new Date(rebalance.timestamp * 1000),
        from: addressToArkName.get(rebalance.from.id.toLowerCase()),
        to: addressToArkName.get(rebalance.to.id.toLowerCase()),
        amount: roundToSixDecimals(parseFloat(rebalance.amountUSD)),
      })),
      ...ark.rebalancesTo.map((rebalance) => ({
        timestamp: new Date(rebalance.timestamp * 1000),
        from: addressToArkName.get(rebalance.from.id.toLowerCase()),
        to: addressToArkName.get(rebalance.to.id.toLowerCase()),
        amount: roundToSixDecimals(parseFloat(rebalance.amountUSD)),
      })),
    ])

    return { chartData, rebalances }
  }, [data, arkNames])

  if (!data) {
    return (
      <div className="flex justify-center items-center h-screen">
        <div className="animate-spin rounded-full h-32 w-32 border-t-2 border-b-2 border-purple-500"></div>
      </div>
    )
  }

  const { chartData, rebalances } = processedData
  console.log('Chart data length:', chartData.length)
  console.log('Rebalances length:', rebalances.length)
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

  const toggleView = () => setShowAPR(!showAPR)

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
  console.log('Rendering component, showAPR:', showAPR)
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
          <LineChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
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
                    dot={
                      <CustomizedDot rebalances={rebalances} colors={colors} arkNames={arkNames} />
                    }
                    animationDuration={1000}
                  />
                ))}
              </>
            )}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}

export default GraphQLChartComponent
