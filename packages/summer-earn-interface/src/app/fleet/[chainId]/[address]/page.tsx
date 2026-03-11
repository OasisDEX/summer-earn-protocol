'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { useParams } from 'next/navigation'
import { useAccount } from 'wagmi'

import { Ark } from '../../../../components/Ark'
import { AuctionConfigModal } from '../../../../components/AuctionConfigModal'
import { DepositWithdrawTabs } from '../../../../components/DepositWithdrawTabs'
import { FleetManagementForm } from '../../../../components/FleetManagementForm'
import { GlassCard } from '../../../../components/GlassCard'
import { ProgressBar } from '../../../../components/ProgressBar'
import { RebalanceForm } from '../../../../components/RebalanceForm'
import { StakingSection } from '../../../../components/StakingSection'
import { useFleetActions } from '../../../../hooks/useFleetActions'
import { useFleetArks } from '../../../../hooks/useFleetArks'
import { useFleetInfo } from '../../../../hooks/useFleetInfo'
import { useRebalance } from '../../../../hooks/useRebalance'
import { useSyncWalletChain } from '../../../../hooks/useSyncWalletChain'
import { ChainId, RebalanceData } from '../../../../types'
import {
  formatDecimalOutput,
  formatPercentage,
  parseDecimalInput,
} from '../../../../utils/decimals'

export default function FleetDetail() {
  const params = useParams()
  const address = params.address as `0x${string}`
  const chainId = params.chainId as ChainId
  const [assetInfo, setAssetInfo] = useState({ symbol: '', decimals: 18 })
  useSyncWalletChain(chainId)
  const [isFleetManagementOpen, setIsFleetManagementOpen] = useState(false)
  // Amount state removed - now handled in individual tab components

  const { isConnected } = useAccount()
  const {
    fleetInfo,
    userInfo,
    loading: fleetLoading,
    error: fleetError,
    updateAllowance,
  } = useFleetInfo({ address, chainId })
  const {
    arks,
    loading: arksLoading,
    refetch: refetchArks,
  } = useFleetArks({
    fleetAddress: address,
    chainId,
  })

  const {
    approve,
    deposit,
    withdraw,
    isApproveLoading,
    isDepositLoading,
    isWithdrawLoading,
    isApproveSuccess,
  } = useFleetActions({
    fleetAddress: address,
    assetAddress: (fleetInfo?.asset as `0x${string}`) || '0x',
    assetDecimals: assetInfo.decimals,
    chainId,
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
    chainId,
  })
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

  const handleRebalance = (rebalanceData: RebalanceData[]) => {
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

  // Optimistically update allowance after successful approval
  useEffect(() => {
    if (isApproveSuccess) {
      // Set allowance to max uint256 since approval succeeded
      updateAllowance(BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'))
    }
  }, [isApproveSuccess, updateAllowance])

  if (fleetError || (!fleetLoading && !fleetInfo)) {
    return (
      <div className="max-w-7xl mx-auto px-6 py-8">
        <div className="mb-8">
          <Link href="/" className="text-slate-400 hover:text-white text-sm mb-4 inline-block">
            ← Back to Fleets
          </Link>
          <h1 className="text-2xl font-bold text-white">Fleet Details</h1>
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
        </div>
      </div>
    )
  }

  return (
    <div>
      {/* Page title row: Back + Fleet name */}
      <div className="flex items-center gap-3 mb-8">
        <Link href="/" className="text-slate-400 hover:text-white transition-colors text-sm">
          ← Back to Fleets
        </Link>
        <span className="text-slate-600">|</span>
        {fleetInfo ? (
          <>
            <h1 className="text-2xl font-bold text-white">
              {fleetInfo.name} ({fleetInfo.symbol})
            </h1>
            {isConnected && userInfo && userInfo.balance > BigInt(0) && (
              <span className="px-2.5 py-1 bg-primary/20 text-primary text-xs font-medium rounded-lg">
                Active
              </span>
            )}
          </>
        ) : (
          <div className="h-8 w-64 bg-white/5 rounded-md animate-pulse" />
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Fleet Information & User Actions */}
        <div className="space-y-6">
          <GlassCard>
            <h2 className="text-lg font-semibold text-white mb-6">Fleet Information</h2>

            {fleetInfo ? (
              <div className="space-y-4">
                <div>
                  <p className="text-sm text-slate-500 mb-1">Fleet Address</p>
                  <p className="font-mono text-slate-300 break-all text-sm">{fleetInfo.address}</p>
                </div>

                <div>
                  <p className="text-sm text-slate-500 mb-1">Asset</p>
                  <p className="font-mono text-slate-300 break-all text-sm">{fleetInfo.asset}</p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-slate-500 mb-1">Total Assets</p>
                    <p className="text-lg font-semibold text-white">
                      {formatDecimalOutput(fleetInfo.totalAssets, assetInfo.decimals)}{' '}
                      {assetInfo.symbol}
                    </p>
                  </div>

                  <div>
                    <p className="text-sm text-slate-500 mb-1">Withdrawable</p>
                    <p className="text-lg font-semibold text-white">
                      {formatDecimalOutput(fleetInfo.withdrawableTotalAssets, assetInfo.decimals)}{' '}
                      {assetInfo.symbol}
                    </p>
                  </div>
                </div>

                {fleetInfo.depositCap > BigInt(0) && (
                  <div>
                    <div className="flex justify-between text-sm mb-2">
                      <span className="text-slate-500">Deposit Cap</span>
                      <span className="text-white">
                        {formatPercentage(
                          (fleetInfo.totalAssets * BigInt(100) * BigInt(10 ** 18)) /
                            fleetInfo.depositCap,
                        )}{' '}
                        used
                      </span>
                    </div>
                    <ProgressBar
                      value={
                        Number(
                          (fleetInfo.totalAssets * BigInt(100) * BigInt(10 ** 18)) /
                            fleetInfo.depositCap,
                        ) / 1e18
                      }
                      max={100}
                    />
                  </div>
                )}
              </div>
            ) : (
              <div className="space-y-4">
                <div>
                  <div className="h-4 w-24 bg-white/10 rounded mb-2 animate-pulse" />
                  <div className="h-4 w-full bg-white/10 rounded animate-pulse" />
                </div>
                <div>
                  <div className="h-4 w-24 bg-white/10 rounded mb-2 animate-pulse" />
                  <div className="h-4 w-full bg-white/10 rounded animate-pulse" />
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <div className="h-4 w-28 bg-white/10 rounded mb-2 animate-pulse" />
                    <div className="h-6 w-40 bg-white/10 rounded animate-pulse" />
                  </div>
                  <div>
                    <div className="h-4 w-32 bg-white/10 rounded mb-2 animate-pulse" />
                    <div className="h-6 w-40 bg-white/10 rounded animate-pulse" />
                  </div>
                </div>
              </div>
            )}
          </GlassCard>

          {isConnected && userInfo && fleetInfo && (
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-6">Your Position</h3>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-slate-500 mb-1">Your Fleet Tokens</p>
                  <p className="text-lg font-semibold text-white">
                    {formatDecimalOutput(userInfo.balance, fleetInfo.fleetDecimals)}{' '}
                    {fleetInfo.symbol}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-slate-500 mb-1">Your {assetInfo.symbol} Balance</p>
                  <p className="text-lg font-semibold text-white">
                    {formatDecimalOutput(userInfo.underlyingBalance, assetInfo.decimals)}{' '}
                    {assetInfo.symbol}
                  </p>
                </div>
              </div>
            </GlassCard>
          )}

          {/* Debug Info (Development Only) */}
          {/* <DebugStakingInfo fleetAddress={address} chainId={chainId} userInfo={userInfo} /> */}

          {/* Deposit/Withdraw Tabs */}
          {isConnected && userInfo && fleetInfo && (
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

          {/* Staking Section */}
          {isConnected && userInfo && fleetInfo && (
            <StakingSection
              fleetAddress={address}
              fleetSymbol={fleetInfo.symbol}
              fleetDecimals={fleetInfo.fleetDecimals}
              chainId={chainId}
              userInfo={userInfo}
            />
          )}
        </div>

        {/* Right Column - Arks and Rebalance */}
        <div className="space-y-6">
          {/* Arks Section */}
          <GlassCard>
            <h2 className="text-lg font-semibold text-white mb-6">Active Fleet Arks</h2>

            {arksLoading ? (
              <div className="text-center text-slate-400">Loading arks...</div>
            ) : arks.length === 0 ? (
              <div className="text-center text-slate-500">No arks found for this fleet.</div>
            ) : (
              <div className="space-y-4">
                {arks.map((ark) => (
                  <div key={ark.address} className="glass rounded-xl p-4">
                    <div className="flex justify-between items-start mb-2">
                      <div>
                        <div className="flex items-center gap-2 mb-1">
                          <h4 className="text-white font-semibold">{ark.name}</h4>
                          {ark.isBufferArk && (
                            <span className="px-2 py-0.5 bg-primary/20 text-primary text-xs font-medium rounded-lg">
                              Buffer Ark
                            </span>
                          )}
                          {ark.hasWithdrawalQueue && (
                            <span className="px-2 py-0.5 bg-amber-500/20 text-amber-400 text-xs font-medium rounded-lg">
                              Withdrawal Queue
                            </span>
                          )}
                          {ark.needsSweep && !ark.isBufferArk && (
                            <span className="px-2 py-0.5 bg-orange-500/20 text-orange-400 text-xs font-medium rounded-lg">
                              Needs Sweep
                            </span>
                          )}
                        </div>
                        {ark.withdrawalRequestId != null && (
                          <p className="text-xs text-slate-500 mt-0.5">
                            Withdrawal ID: {ark.withdrawalRequestId}
                          </p>
                        )}
                        <p className="text-slate-500 text-sm font-mono">{ark.address}</p>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4 text-sm mb-4">
                      <div>
                        <p className="text-slate-500">Balance</p>
                        <p className="text-white font-medium">
                          {formatDecimalOutput(ark.totalAssets, assetInfo.decimals)}{' '}
                          {assetInfo.symbol}
                        </p>
                      </div>
                      <div>
                        <p className="text-slate-500">Allocation</p>
                        <p className="text-white font-medium">
                          {fleetInfo &&
                          fleetInfo.totalAssets > BigInt(0) &&
                          ark.totalAssets > BigInt(0)
                            ? formatPercentage(
                                (ark.totalAssets * BigInt(100) * BigInt(10 ** 18)) /
                                  fleetInfo.totalAssets,
                              )
                            : '0%'}
                        </p>
                      </div>
                    </div>

                    {/* Ark Configuration Limits */}
                    <div className="border-t border-white/10 pt-4 mt-4">
                      <p className="text-xs text-slate-500 mb-3 font-semibold uppercase tracking-wide">
                        Config Limits
                      </p>
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                          <p className="text-slate-500">Deposit Cap</p>
                          <p className="text-white font-medium">
                            {ark.depositCap === BigInt(0)
                              ? 'Zero'
                              : `${formatDecimalOutput(ark.depositCap, assetInfo.decimals)} ${assetInfo.symbol}`}
                          </p>
                          {ark.depositCap > BigInt(0) && (
                            <p className="text-xs text-slate-500 mt-1">
                              {formatPercentage(
                                (ark.totalAssets * BigInt(100) * BigInt(10 ** 18)) / ark.depositCap,
                              )}{' '}
                              of cap used
                            </p>
                          )}
                        </div>
                        <div>
                          <p className="text-slate-500">Max Deposit % of TVL</p>
                          <p className="text-white font-medium">
                            {ark.maxDepositPercentageOfTVL === BigInt(0)
                              ? 'Zero'
                              : formatPercentage(ark.maxDepositPercentageOfTVL)}
                          </p>
                          {fleetInfo &&
                            fleetInfo.totalAssets > BigInt(0) &&
                            ark.totalAssets > BigInt(0) && (
                              <p className="text-xs text-slate-500 mt-1">
                                Current:{' '}
                                {formatPercentage(
                                  (ark.totalAssets * BigInt(100) * BigInt(10 ** 18)) /
                                    fleetInfo.totalAssets,
                                )}{' '}
                                of fleet TVL
                              </p>
                            )}
                        </div>
                        <div>
                          <p className="text-slate-500">Max Rebalance Inflow</p>
                          <p className="text-white font-medium">
                            {ark.maxRebalanceInflow ===
                            BigInt(
                              '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
                            )
                              ? 'Unlimited'
                              : `${formatDecimalOutput(ark.maxRebalanceInflow, assetInfo.decimals)} ${assetInfo.symbol}`}
                          </p>
                        </div>
                        <div>
                          <p className="text-slate-500">Max Rebalance Outflow</p>
                          <p className="text-white font-medium">
                            {ark.maxRebalanceOutflow ===
                            BigInt(
                              '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
                            )
                              ? 'Unlimited'
                              : `${formatDecimalOutput(ark.maxRebalanceOutflow, assetInfo.decimals)} ${assetInfo.symbol}`}
                          </p>
                        </div>
                      </div>
                    </div>
                    <Ark
                      arkAddress={ark.address as `0x${string}`}
                      rewardToken={(fleetInfo?.asset as `0x${string}`) || '0x'}
                      name={ark.name}
                      fleetAddress={address}
                      assetDecimals={assetInfo.decimals}
                      assetSymbol={assetInfo.symbol}
                      isBufferArk={ark.isBufferArk}
                      hasWithdrawalQueue={ark.hasWithdrawalQueue}
                      withdrawalRequestId={ark.withdrawalRequestId}
                      assetsInWithdrawalQueue={ark.assetsInWithdrawalQueue}
                      isWithdrawalClaimRequired={ark.isWithdrawalClaimRequired}
                      assetBalance={ark.assetBalance}
                      needsSweep={ark.needsSweep}
                      onWithdrawalSuccess={() => refetchArks()}
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
          </GlassCard>

          {/* Fleet Optimization - Rebalance */}
          <RebalanceForm
            arks={arks}
            assetSymbol={assetInfo.symbol}
            assetDecimals={assetInfo.decimals}
            onRebalance={handleRebalance}
            isLoading={isRebalanceLoading}
          />

          {/* Advanced Fleet Management */}
          <GlassCard>
            <button
              onClick={() => setIsFleetManagementOpen(!isFleetManagementOpen)}
              className="w-full flex items-center justify-between text-white py-3 px-1 rounded-md hover:bg-white/5 transition-colors"
            >
              <span className="text-lg font-semibold">Advanced Fleet Management</span>
              <span
                className={`transform transition-transform ${isFleetManagementOpen ? 'rotate-180' : ''}`}
              >
                ▼
              </span>
            </button>

            {isFleetManagementOpen && (
              <FleetManagementForm
                fleetAddress={address}
                chainId={chainId}
                assetDecimals={assetInfo.decimals}
                assetSymbol={assetInfo.symbol}
                fleetInfo={fleetInfo}
                arks={arks}
              />
            )}
          </GlassCard>
        </div>
      </div>
    </div>
  )
}
