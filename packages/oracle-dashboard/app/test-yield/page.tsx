'use client'

import { useState, useEffect } from 'react'
import { useReadContract } from 'wagmi'
import { TEST_YIELD_FACTORY_ABI, TEST_YIELD_TOKEN_ABI, ERC20_ABI } from '../../config/abis'
import { type Address, formatUnits } from 'viem'
import { DashboardHeader } from '../../components/dashboard/DashboardHeader'
import { type NetworkType } from '../../hooks/useOracleData'
import yieldDeployments from '../../lib/yield-deployments.json'
import { YieldActionModal } from '../../components/YieldActionModal'

// Type for the JSON import
type YieldDeploymentFile = Record<string, { chainId: number; factoryAddress: string }>

// Component for a single row
function YieldContractRow({
  address,
  onAction,
}: {
  address: Address
  factoryAddress: Address
  onAction: (action: 'deposit' | 'withdraw', ticker: string, tokenAddress: Address) => void
}) {
  const { data: symbol } = useReadContract({
    address,
    abi: [
      {
        name: 'symbol',
        inputs: [],
        outputs: [{ type: 'string' }],
        type: 'function',
        stateMutability: 'view',
      },
    ] as const,
    functionName: 'symbol',
  })

  const { data: usdcAddress } = useReadContract({
    address,
    abi: TEST_YIELD_TOKEN_ABI,
    functionName: 'usdc',
  })

  const { data: pocketAddress } = useReadContract({
    address,
    abi: TEST_YIELD_TOKEN_ABI,
    functionName: 'pocket',
  })

  const { data: totalSupply } = useReadContract({
    address,
    abi: TEST_YIELD_TOKEN_ABI,
    functionName: 'totalSupply',
  })

  const { data: contractUsdcBal } = useReadContract({
    address: usdcAddress as Address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: !!usdcAddress },
  })

  const { data: pocketUsdcBal } = useReadContract({
    address: usdcAddress as Address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [pocketAddress!],
    query: { enabled: !!usdcAddress && !!pocketAddress },
  })

  const totalUsdc = (contractUsdcBal ?? BigInt(0)) + (pocketUsdcBal ?? BigInt(0))

  return (
    <tr className="border-b border-gray-700 hover:bg-gray-900 transition-colors">
      <td className="p-4 font-bold text-blue-400">{symbol || '...'}</td>
      <td className="p-4 font-mono text-xs text-gray-400">{address}</td>
      <td className="p-4 font-mono text-xs text-gray-400">{pocketAddress || '...'}</td>
      <td className="p-4 text-right font-mono">
        {contractUsdcBal !== undefined ? formatUnits(contractUsdcBal, 6) : '-'}
      </td>
      <td className="p-4 text-right font-mono">
        {pocketUsdcBal !== undefined ? formatUnits(pocketUsdcBal, 6) : '-'}
      </td>
      <td className="p-4 text-right font-mono font-bold text-green-400">
        {formatUnits(totalUsdc, 6)}
      </td>
      <td className="p-4 text-right font-mono">
        {totalSupply !== undefined ? formatUnits(totalSupply, 18) : '-'}
      </td>
      <td className="p-4 text-right">
        <div className="flex gap-2 justify-end">
          <button
            onClick={() => symbol && onAction('deposit', symbol, address)}
            className="px-3 py-1 bg-green-600/20 text-green-400 hover:bg-green-600/30 rounded text-xs font-bold uppercase tracking-wide transition-colors"
          >
            Deposit
          </button>
          <button
            onClick={() => symbol && onAction('withdraw', symbol, address)}
            className="px-3 py-1 bg-red-600/20 text-red-400 hover:bg-red-600/30 rounded text-xs font-bold uppercase tracking-wide transition-colors"
          >
            Withdraw
          </button>
        </div>
      </td>
    </tr>
  )
}

export default function TestYieldPage() {
  const getNetworkFactory = (network: NetworkType) => {
    const deployments = yieldDeployments as YieldDeploymentFile
    const networkKey = network === 'mainnet' ? 'ethereum' : network
    const chainData = deployments[networkKey]
    if (chainData?.factoryAddress && /^0x[a-fA-F0-9]{40}$/.test(chainData.factoryAddress)) {
      return chainData.factoryAddress
    }
    return ''
  }

  const initialFactory = getNetworkFactory('base')
  const [factoryAddress, setFactoryAddress] = useState<Address | ''>(initialFactory as Address | '')
  const [inputAddr, setInputAddr] = useState<string>(initialFactory)
  const [selectedNetwork, setSelectedNetwork] = useState<NetworkType>('base')

  const handleNetworkChange = (network: NetworkType) => {
    setSelectedNetwork(network)
    const newFactory = getNetworkFactory(network)
    setFactoryAddress(newFactory as Address | '')
    setInputAddr(newFactory)
  }

  const [modalOpen, setModalOpen] = useState(false)
  const [modalAction, setModalAction] = useState<'deposit' | 'withdraw'>('deposit')
  const [selectedTicker, setSelectedTicker] = useState('')
  const [selectedTokenAddress, setSelectedTokenAddress] = useState<Address | undefined>()

  const {
    data: allTickers,
    isError,
    isLoading,
    refetch,
    error: readContractError,
  } = useReadContract({
    address: factoryAddress as Address,
    abi: TEST_YIELD_FACTORY_ABI,
    functionName: 'getAllTickers',
    query: {
      enabled: !!factoryAddress && /^0x[a-fA-F0-9]{40}$/.test(factoryAddress),
    },
  })

  const handleAction = (action: 'deposit' | 'withdraw', ticker: string, tokenAddress: Address) => {
    setModalAction(action)
    setSelectedTicker(ticker)
    setSelectedTokenAddress(tokenAddress)
    setModalOpen(true)
  }

  return (
    <div className="min-h-screen bg-black text-white">
      <DashboardHeader
        title="Test Yield Contracts"
        selectedNetwork={selectedNetwork}
        onNetworkChange={handleNetworkChange}
        loading={isLoading}
        onRefresh={() => refetch()}
        onBatchUpdate={() => {}}
        canBatchUpdate={false}
        isSelectionMode={false}
        selectedCount={0}
        onCancelSelection={() => {}}
      />

      <div className="p-8 max-w-7xl mx-auto">
        <div className="flex gap-4 mb-8 bg-gray-900 p-6 rounded-lg border border-gray-800">
          <div className="flex-1">
            <label className="block text-sm text-gray-400 mb-2">Factory Address</label>
            <div className="flex gap-2">
              <input
                type="text"
                placeholder="0x..."
                className="bg-black border border-gray-700 p-2 rounded w-full font-mono focus:border-blue-500 outline-none"
                value={inputAddr}
                onChange={(e) => setInputAddr(e.target.value)}
              />
              <button
                onClick={() => setFactoryAddress(inputAddr as Address)}
                className="bg-blue-600 px-6 py-2 rounded hover:bg-blue-500 font-medium transition-colors"
              >
                Load
              </button>
            </div>
          </div>
        </div>

        {isLoading && <div className="text-center py-8">Loading factory data...</div>}
        {isError && (
          <div className="text-red-500 bg-red-900/20 p-4 rounded border border-red-900 mb-8">
            Error loading factory data. Check address and network. {readContractError?.message}
          </div>
        )}

        {allTickers && (
          <div className="overflow-x-auto bg-gray-900/50 rounded-lg border border-gray-800">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-gray-700 text-gray-400 text-sm uppercase tracking-wider">
                  <th className="p-4 font-medium">Ticker</th>
                  <th className="p-4 font-medium">Contract Address</th>
                  <th className="p-4 font-medium">Pocket Address</th>
                  <th className="p-4 font-medium text-right">Main USDC</th>
                  <th className="p-4 font-medium text-right">Pocket USDC</th>
                  <th className="p-4 font-medium text-right">Total USDC</th>
                  <th className="p-4 font-medium text-right">Shares Supply</th>
                  <th className="p-4 font-medium text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-800">
                {allTickers.length === 0 && (
                  <tr>
                    <td colSpan={8} className="p-8 text-center text-gray-500">
                      No contracts deployed yet.
                    </td>
                  </tr>
                )}
                {allTickers.map((addr) => (
                  <YieldContractRow
                    key={addr}
                    address={addr}
                    factoryAddress={factoryAddress as Address}
                    onAction={handleAction}
                  />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {factoryAddress && (
        <YieldActionModal
          isOpen={modalOpen}
          onClose={() => setModalOpen(false)}
          action={modalAction}
          ticker={selectedTicker}
          factoryAddress={factoryAddress as Address}
          tokenAddress={selectedTokenAddress}
        />
      )}
    </div>
  )
}
