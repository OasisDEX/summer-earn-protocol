'use client'

import Link from 'next/link'
import { useParams } from 'next/navigation'
import { useEffect, useState } from 'react'
import { formatUnits } from 'viem'
import { useAccount } from 'wagmi'
import { useRaftContract } from '../../../../components/../contracts/Raft'
import { Ark } from '../../../../components/Ark'
import { AuctionConfigModal } from '../../../../components/AuctionConfigModal'
import { ChainSelector } from '../../../../components/ChainSelector'
import { ConnectButton } from '../../../../components/ConnectButton'
import { useFleetActions } from '../../../../hooks/useFleetActions'
import { useFleetArks } from '../../../../hooks/useFleetArks'
import { useFleetInfo } from '../../../../hooks/useFleetInfo'
import { useRebalance } from '../../../../hooks/useRebalance'
import { ChainId, RebalanceData } from '../../../../types'

export default function FleetDetail() {
  const params = useParams()
  const address = params.address as `0x${string}`
  const chainId = params.chainId as ChainId
  const [selectedChain, setSelectedChain] = useState<ChainId>(chainId)
  const [assetInfo, setAssetInfo] = useState({ symbol: '', decimals: 18 })
  const [amount, setAmount] = useState('')

  // For rebalance operations
  const [fromArk, setFromArk] = useState<`0x${string}`>('0x')
  const [toArk, setToArk] = useState<`0x${string}`>('0x')
  const [rebalanceAmount, setRebalanceAmount] = useState('')
  const [boardData, setBoardData] = useState('0x')
  const [disembarkData, setDisembarkData] = useState('0x')

  const { isConnected } = useAccount()
  const {
    fleetInfo,
    userInfo,
    loading: fleetLoading,
  } = useFleetInfo({ address, chainId: selectedChain })
  const { arks, loading: arksLoading } = useFleetArks({
    fleetAddress: address,
    chainId: selectedChain,
  })

  const { approve, deposit, withdraw, isApproveLoading, isDepositLoading, isWithdrawLoading } =
    useFleetActions({
      fleetAddress: address,
      assetAddress: (fleetInfo?.asset as `0x${string}`) || '0x',
      assetDecimals: assetInfo.decimals,
    })

  const { rebalance, isRebalanceLoading } = useRebalance({ fleetAddress: address })

  const { harvest, harvestAndStartAuction } = useRaftContract()
  const [auctionModalArk, setAuctionModalArk] = useState<null | {
    address: string
    rewardToken: string
    name: string
  }>(null)

  const needsApproval =
    userInfo && userInfo.allowance < BigInt(amount || '0') && BigInt(amount || '0') > BigInt(0)

  const handleDeposit = () => {
    if (!fleetInfo) return
    if (needsApproval) {
      approve(amount)
    } else {
      deposit(amount)
    }
  }

  const handleWithdraw = () => {
    if (!fleetInfo) return
    withdraw(amount)
  }

  const handleRebalance = () => {
    if (!fromArk || !toArk || !rebalanceAmount || !fleetInfo) return

    const rebalanceData: RebalanceData[] = [
      {
        fromArk,
        toArk,
        amount: BigInt(rebalanceAmount),
        boardData: boardData as `0x${string}`,
        disembarkData: disembarkData as `0x${string}`,
      },
    ]

    rebalance(rebalanceData)
  }

  // Fetch asset info when fleet info is available
  useEffect(() => {
    if (fleetInfo && fleetInfo.asset) {
      setAssetInfo({
        symbol: fleetInfo.assetSymbol,
        decimals: fleetInfo.assetDecimals,
      })
    }
  }, [fleetInfo])

  if (fleetLoading) {
    return (
      <main className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold">Fleet Details</h1>
          <ConnectButton />
        </div>
        <p>Loading fleet information...</p>
      </main>
    )
  }

  if (!fleetInfo) {
    return (
      <main className="container mx-auto px-4 py-8">
        <div className="flex justify-between items-center mb-8 bg-gray-400">
          <h1 className="text-3xl font-bold">Fleet Details</h1>
          <ConnectButton />
        </div>
        <p>Fleet not found. Please check the address and try again.</p>
        <Link href="/" className="text-blue-600 hover:underline mt-4 inline-block">
          Back to Home
        </Link>
      </main>
    )
  }

  return (
    <main className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <div>
          <Link href="/" className="text-blue-600 hover:underline mb-2 inline-block">
            &larr; Back to Home
          </Link>
          <h1 className="text-3xl font-bold">
            {fleetInfo.name} ({fleetInfo.symbol})
          </h1>
        </div>
        <ConnectButton />
      </div>

      <div className="mb-8">
        <ChainSelector selectedChain={selectedChain} onChange={setSelectedChain} />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="bg-gray-400 shadow rounded-lg p-6">
          <h2 className="text-xl font-bold mb-4">Fleet Information</h2>

          <div className="space-y-4">
            <div>
              <p className="text-sm text-gray-800">Address</p>
              <p className="font-medium break-all">{fleetInfo.address}</p>
            </div>

            <div>
              <p className="text-sm text-gray-800">Asset</p>
              <p className="font-medium break-all">{fleetInfo.asset}</p>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-sm text-gray-800">Total Assets</p>
                <p className="font-medium">
                  {formatUnits(fleetInfo.totalAssets, assetInfo.decimals)} {assetInfo.symbol}
                </p>
              </div>

              <div>
                <p className="text-sm text-gray-800">Withdrawable Assets</p>
                <p className="font-medium">
                  {formatUnits(fleetInfo.withdrawableTotalAssets, assetInfo.decimals)}{' '}
                  {assetInfo.symbol}
                </p>
              </div>
            </div>
          </div>

          {isConnected && userInfo && (
            <div className="mt-6 border-t pt-4">
              <h3 className="text-lg font-semibold mb-3">Your Position</h3>

              <div className="grid grid-cols-2 gap-4 mb-4">
                <div>
                  <p className="text-sm text-gray-800">Your Balance</p>
                  <p className="font-medium">
                    {formatUnits(userInfo.balance, assetInfo.decimals)} {fleetInfo.symbol}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-800">Your {assetInfo.symbol} Balance</p>
                  <p className="font-medium">
                    {formatUnits(userInfo.underlyingBalance, assetInfo.decimals)} {assetInfo.symbol}
                  </p>
                </div>
              </div>

              <div className="mb-4">
                <label htmlFor="amount" className="block text-sm font-medium text-gray-800 mb-1">
                  Amount
                </label>
                <input
                  type="text"
                  id="amount"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder={`Amount in ${assetInfo.symbol}`}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              <div className="flex space-x-2">
                <button
                  onClick={handleDeposit}
                  disabled={isApproveLoading || isDepositLoading || !amount}
                  className="flex-1 bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 disabled:bg-gray-400"
                >
                  {isApproveLoading
                    ? 'Approving...'
                    : isDepositLoading
                      ? 'Depositing...'
                      : needsApproval
                        ? 'Approve'
                        : 'Deposit'}
                </button>
                <button
                  onClick={handleWithdraw}
                  disabled={isWithdrawLoading || !amount}
                  className="flex-1 bg-gray-600 text-white py-2 px-4 rounded-md hover:bg-gray-700 disabled:bg-gray-400"
                >
                  {isWithdrawLoading ? 'Withdrawing...' : 'Withdraw'}
                </button>
              </div>
            </div>
          )}
        </div>

        <div className="bg-gray-400 shadow rounded-lg p-6">
          <h2 className="text-xl font-bold mb-4">Arks</h2>

          {arksLoading ? (
            <p>Loading arks...</p>
          ) : arks.length === 0 ? (
            <p>No arks found for this fleet.</p>
          ) : (
            <div className="space-y-4">
              {arks.map((ark) => (
                <Ark
                  key={ark.address}
                  arkAddress={ark.address as `0x${string}`}
                  rewardToken={fleetInfo.asset as `0x${string}`}
                  name={ark.name}
                />
              ))}
            </div>
          )}

          {auctionModalArk && (
            <AuctionConfigModal
              isOpen={!!auctionModalArk}
              onClose={() => setAuctionModalArk(null)}
              arkAddress={auctionModalArk.address as `0x${string}`}
              rewardToken={auctionModalArk.rewardToken as `0x${string}`}
            />
          )}

          <div className="mt-8 border-t pt-4">
            <h3 className="text-lg font-semibold mb-3">Rebalance</h3>

            <div className="space-y-4">
              <div>
                <label htmlFor="fromArk" className="block text-sm font-medium text-gray-800 mb-1">
                  From Ark
                </label>
                <select
                  id="fromArk"
                  value={fromArk}
                  onChange={(e) => setFromArk(e.target.value as `0x${string}`)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 bg-gray-400"
                >
                  <option value="0x">Select Ark</option>
                  {arks.map((ark) => (
                    <option key={`from-${ark.address}`} value={ark.address as `0x${string}`}>
                      {ark.address} - {ark.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label htmlFor="toArk" className="block text-sm font-medium text-gray-800 mb-1">
                  To Ark
                </label>
                <select
                  id="toArk"
                  value={toArk}
                  onChange={(e) => setToArk(e.target.value as `0x${string}`)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 bg-gray-400"
                >
                  <option value="0x">Select Ark</option>
                  {arks.map((ark) => (
                    <option key={`to-${ark.address}`} value={ark.address as `0x${string}`}>
                      {ark.address} - {ark.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  htmlFor="rebalanceAmount"
                  className="block text-sm font-medium text-gray-800 mb-1"
                >
                  Amount
                </label>
                <input
                  type="text"
                  id="rebalanceAmount"
                  value={rebalanceAmount}
                  onChange={(e) => setRebalanceAmount(e.target.value)}
                  placeholder={`Amount in ${assetInfo.symbol}`}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              <div>
                <label htmlFor="boardData" className="block text-sm font-medium text-gray-800 mb-1">
                  Board Data
                </label>
                <input
                  type="text"
                  id="boardData"
                  value={boardData}
                  onChange={(e) => setBoardData(e.target.value)}
                  placeholder="0x"
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              <div>
                <label
                  htmlFor="disembarkData"
                  className="block text-sm font-medium text-gray-800 mb-1"
                >
                  Disembark Data
                </label>
                <input
                  type="text"
                  id="disembarkData"
                  value={disembarkData}
                  onChange={(e) => setDisembarkData(e.target.value)}
                  placeholder="0x"
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              <button
                onClick={handleRebalance}
                disabled={
                  isRebalanceLoading ||
                  !fromArk ||
                  !toArk ||
                  !rebalanceAmount ||
                  fromArk === '0x' ||
                  toArk === '0x'
                }
                className="w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 disabled:bg-gray-400"
              >
                {isRebalanceLoading ? 'Rebalancing...' : 'Rebalance'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}
