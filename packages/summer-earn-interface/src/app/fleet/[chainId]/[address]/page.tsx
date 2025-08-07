'use client'

import Link from 'next/link'
import { useParams, useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'
import { useAccount } from 'wagmi'
import { useRaftContract } from '../../../../components/../contracts/Raft'
import { Ark } from '../../../../components/Ark'
import { AuctionConfigModal } from '../../../../components/AuctionConfigModal'
import { ChainSelector } from '../../../../components/ChainSelector'
import { ConnectButton } from '../../../../components/ConnectButton'
import { DepositWithdrawTabs } from '../../../../components/DepositWithdrawTabs'
import { FleetManagementForm } from '../../../../components/FleetManagementForm'
import { RebalanceForm } from '../../../../components/RebalanceForm'
import { StakingSection } from '../../../../components/StakingSection'
import { useFleetActions } from '../../../../hooks/useFleetActions'
import { useFleetArks } from '../../../../hooks/useFleetArks'
import { useFleetInfo } from '../../../../hooks/useFleetInfo'
import { useRebalance } from '../../../../hooks/useRebalance'
import { useStakingRewards } from '../../../../hooks/useStakingRewards'
import { ChainId, RebalanceData } from '../../../../types'
import { formatDecimalOutput, parseDecimalInput } from '../../../../utils/decimals'

export default function FleetDetail() {
  const params = useParams()
  const router = useRouter()
  const address = params.address as `0x${string}`
  const chainId = params.chainId as ChainId
  const [selectedChain, setSelectedChain] = useState<ChainId>(chainId)
  const [assetInfo, setAssetInfo] = useState({ symbol: '', decimals: 18 })
  const [isFleetManagementOpen, setIsFleetManagementOpen] = useState(false)
  // Amount state removed - now handled in individual tab components

  const { isConnected } = useAccount()
  const {
    fleetInfo,
    userInfo,
    loading: fleetLoading,
    error: fleetError,
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

  // Calculate if approval is needed
  const needsApproval = (amount: string) => {
    if (!userInfo || !amount || amount === '0') return false
    try {
      const parsedAmount = parseDecimalInput(amount, assetInfo.decimals)
      return userInfo.allowance < parsedAmount
    } catch {
      return false
    }
  }

  const { rebalance, isRebalanceLoading } = useRebalance({
    fleetAddress: address,
    chainId: selectedChain,
  })

  // Staking rewards hook
  const {
    stakingRewardsManagerAddress,
    stakedBalance,
    approveStaking,
    stake: stakeShares,
    needsStakingApproval,
    isApproveStakingLoading,
    isStakeLoading,
    isApproveStakingConfirmed,
    isStakeConfirmed,
  } = useStakingRewards({
    fleetAddress: address,
    chainId: selectedChain,
  })

  const { harvest, harvestAndStartAuction } = useRaftContract()
  const [auctionModalArk, setAuctionModalArk] = useState<null | {
    address: string
    rewardToken: string
    name: string
  }>(null)

  const handleApprove = () => {
    approve('1000000000') // Use a default large amount for approval
  }

  const handleDeposit = (amount: string, parsedAmount: bigint) => {
    if (parsedAmount > BigInt(0)) {
      deposit(amount)
    }
  }

  const handleWithdraw = (amount: string, parsedAmount: bigint) => {
    if (parsedAmount > BigInt(0)) {
      withdraw(amount)
    }
  }

  const handleRebalance = (data: {
    fromArk: `0x${string}`
    toArk: `0x${string}`
    amount: bigint
    boardData: `0x${string}`
    disembarkData: `0x${string}`
  }) => {
    const rebalanceData: RebalanceData[] = [data]
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
      <main className="min-h-screen bg-black p-8">
        <div className="max-w-7xl mx-auto">
          <div className="flex justify-between items-center mb-8">
            <h1 className="text-3xl font-bold text-white">Fleet Details</h1>
            <ConnectButton />
          </div>
          <div className="text-center text-gray-300">Loading fleet information...</div>
        </div>
      </main>
    )
  }

  if (fleetError || (!fleetLoading && !fleetInfo)) {
    return (
      <main className="min-h-screen bg-black p-8">
        <div className="max-w-7xl mx-auto">
          <div className="flex justify-between items-center mb-8">
            <h1 className="text-3xl font-bold text-white">Fleet Details</h1>
            <ConnectButton />
          </div>
          <div className="text-center text-red-400 mb-4">
            {fleetError
              ? 'Error loading fleet:'
              : 'Fleet not found. Please check the address and try again.'}
          </div>
          {fleetError && (
            <div className="text-center text-gray-400 text-sm mb-4 bg-gray-800 p-4 rounded">
              <strong>Error details:</strong> {fleetError.message}
            </div>
          )}
          <Link href="/" className="text-blue-400 hover:text-blue-300 mt-4 inline-block">
            ← Back to Home
          </Link>
        </div>
      </main>
    )
  }

  return (
    <main className="min-h-screen bg-black p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="flex justify-between items-center mb-8">
          <div>
            <div className="flex items-center gap-4 mb-4">
              <button
                onClick={() => router.back()}
                className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-semibold transition-colors"
              >
                ← Back
              </button>
              <h1 className="text-3xl font-bold text-white">
                {fleetInfo.name} ({fleetInfo.symbol})
              </h1>
            </div>
          </div>
        </div>

        {/* Chain Selector */}
        <div className="mb-8">
          <ChainSelector selectedChain={selectedChain} onChange={setSelectedChain} />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Fleet Information & User Actions */}
          <div className="space-y-6">
            <div className="bg-gray-900 p-6 rounded-lg">
              <h2 className="text-xl font-semibold text-white mb-6">Fleet Information</h2>

              <div className="space-y-4">
                <div className="p-4 bg-gray-800 rounded-lg">
                  <p className="text-sm text-gray-400">Fleet Address</p>
                  <p className="font-mono text-blue-300 break-all text-sm">{fleetInfo.address}</p>
                </div>

                <div className="p-4 bg-gray-800 rounded-lg">
                  <p className="text-sm text-gray-400">Asset Address</p>
                  <p className="font-mono text-blue-300 break-all text-sm">{fleetInfo.asset}</p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="p-4 bg-gray-800 rounded-lg">
                    <p className="text-sm text-gray-400">Total Assets</p>
                    <p className="text-lg font-semibold text-white">
                      {formatDecimalOutput(fleetInfo.totalAssets, assetInfo.decimals)}{' '}
                      {assetInfo.symbol}
                    </p>
                  </div>

                  <div className="p-4 bg-gray-800 rounded-lg">
                    <p className="text-sm text-gray-400">Withdrawable Assets</p>
                    <p className="text-lg font-semibold text-white">
                      {formatDecimalOutput(fleetInfo.withdrawableTotalAssets, assetInfo.decimals)}{' '}
                      {assetInfo.symbol}
                    </p>
                  </div>
                </div>
              </div>
            </div>

            {isConnected && userInfo && (
              <div className="bg-gray-900 p-6 rounded-lg">
                <h3 className="text-xl font-semibold text-white mb-6">Your Position</h3>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
                  <div className="p-4 bg-gray-800 rounded-lg">
                    <p className="text-sm text-gray-400">Your Fleet Tokens</p>
                    <p className="text-lg font-semibold text-white">
                      {formatDecimalOutput(userInfo.balance, fleetInfo.fleetDecimals)}{' '}
                      {fleetInfo.symbol}
                    </p>
                  </div>
                  <div className="p-4 bg-gray-800 rounded-lg">
                    <p className="text-sm text-gray-400">Your {assetInfo.symbol} Balance</p>
                    <p className="text-lg font-semibold text-white">
                      {formatDecimalOutput(userInfo.underlyingBalance, assetInfo.decimals)}{' '}
                      {assetInfo.symbol}
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Debug Info (Development Only) */}
            {/* <DebugStakingInfo fleetAddress={address} chainId={selectedChain} userInfo={userInfo} /> */}

            {/* Deposit/Withdraw Tabs */}
            {isConnected && userInfo && (
              <DepositWithdrawTabs
                userInfo={userInfo}
                assetSymbol={assetInfo.symbol}
                assetDecimals={assetInfo.decimals}
                fleetSymbol={fleetInfo.symbol}
                fleetDecimals={fleetInfo.fleetDecimals}
                onDeposit={handleDeposit}
                onWithdraw={handleWithdraw}
                onApprove={handleApprove}
                isApproveLoading={isApproveLoading}
                isDepositLoading={isDepositLoading}
                isWithdrawLoading={isWithdrawLoading}
                needsApproval={needsApproval}
              />
            )}

            {/* Old interface removed - now using tabs above */}
            {false && <div className="hidden"></div>}

            {/* Staking Section */}
            {isConnected && userInfo && (
              <StakingSection
                fleetAddress={address}
                fleetSymbol={fleetInfo.symbol}
                fleetDecimals={fleetInfo.fleetDecimals}
                chainId={selectedChain}
                userInfo={userInfo}
              />
            )}
          </div>

          {/* Right Column - Arks and Rebalance */}
          <div className="space-y-6">
            {/* Arks Section */}
            <div className="bg-gray-900 p-6 rounded-lg">
              <h2 className="text-xl font-semibold text-white mb-6">Fleet Arks</h2>

              {arksLoading ? (
                <div className="text-center text-gray-300">Loading arks...</div>
              ) : arks.length === 0 ? (
                <div className="text-center text-gray-400">No arks found for this fleet.</div>
              ) : (
                <div className="space-y-4">
                  {arks.map((ark) => (
                    <div key={ark.address} className="p-4 bg-gray-800 rounded-lg">
                      <div className="flex justify-between items-start mb-2">
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <h4 className="text-white font-semibold">{ark.name}</h4>
                            {ark.isBufferArk && (
                              <span className="px-2 py-1 bg-blue-600 text-blue-100 text-xs rounded-full">
                                Buffer Ark
                              </span>
                            )}
                          </div>
                          <p className="text-gray-400 text-sm font-mono">{ark.address}</p>
                        </div>
                      </div>
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                          <p className="text-gray-400">Total Assets</p>
                          <p className="text-white font-medium">
                            {formatDecimalOutput(ark.totalAssets, assetInfo.decimals)}{' '}
                            {assetInfo.symbol}
                          </p>
                        </div>
                        <div>
                          <p className="text-gray-400">Withdrawable</p>
                          <p className="text-white font-medium">
                            {formatDecimalOutput(ark.withdrawableTotalAssets, assetInfo.decimals)}{' '}
                            {assetInfo.symbol}
                          </p>
                        </div>
                      </div>
                      <Ark
                        arkAddress={ark.address as `0x${string}`}
                        rewardToken={fleetInfo.asset as `0x${string}`}
                        name={ark.name}
                        fleetAddress={address}
                        assetDecimals={assetInfo.decimals}
                        assetSymbol={assetInfo.symbol}
                      />
                    </div>
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
            </div>

            {/* Rebalance Section */}
            <RebalanceForm
              arks={arks}
              assetSymbol={assetInfo.symbol}
              assetDecimals={assetInfo.decimals}
              onRebalance={handleRebalance}
              isLoading={isRebalanceLoading}
            />

            {/* Fleet Management Section */}
            <div className="bg-white shadow rounded-lg p-6 mt-6">
              <button
                onClick={() => setIsFleetManagementOpen(!isFleetManagementOpen)}
                className="w-full flex items-center justify-between bg-gray-600 text-white py-3 px-4 rounded-md hover:bg-gray-700 mb-4"
              >
                <span className="text-lg font-semibold">Fleet Management</span>
                <span
                  className={`transform transition-transform ${isFleetManagementOpen ? 'rotate-180' : ''}`}
                >
                  ▼
                </span>
              </button>

              {isFleetManagementOpen && (
                <FleetManagementForm
                  fleetAddress={address}
                  chainId={selectedChain}
                  assetDecimals={assetInfo.decimals}
                  assetSymbol={assetInfo.symbol}
                />
              )}
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}
