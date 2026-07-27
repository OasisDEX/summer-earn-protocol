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
import { AddressDisplay, Badge, ErrorState } from '../../../../components/ui'
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
      <div>
        <Link
          href="/"
          className="text-on-surface-variant hover:text-on-surface text-sm mb-6 inline-block transition-colors"
        >
          ← Back to Fleets
        </Link>
        <ErrorState
          title={fleetError ? 'Error loading fleet' : 'Fleet not found'}
          description={fleetError ? fleetError.message : 'Please check the address and try again.'}
        />
      </div>
    )
  }

  return (
    <div>
      {/* Page title row: Back + Fleet name */}
      <div className="flex items-center gap-3 mb-8">
        <Link
          href="/"
          className="text-on-surface-variant hover:text-on-surface transition-colors text-sm whitespace-nowrap"
        >
          ← Back to Fleets
        </Link>
        <span className="text-outline-variant">|</span>
        {fleetInfo ? (
          <>
            <h1
              className="text-2xl font-headline font-bold text-on-surface truncate"
              title={`${fleetInfo.name} (${fleetInfo.symbol})`}
            >
              {fleetInfo.name} ({fleetInfo.symbol})
            </h1>
            {isConnected && userInfo && userInfo.balance > BigInt(0) && (
              <Badge tone="primary">Active</Badge>
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
            <h2 className="text-lg font-headline font-semibold text-on-surface mb-6">
              Fleet Information
            </h2>

            {fleetInfo ? (
              <div className="space-y-4">
                <div>
                  <p className="text-sm text-on-surface-variant mb-1">Fleet Address</p>
                  <AddressDisplay
                    value={fleetInfo.address}
                    full
                    className="text-sm text-on-surface/90"
                  />
                </div>

                <div>
                  <p className="text-sm text-on-surface-variant mb-1">Asset</p>
                  <AddressDisplay
                    value={fleetInfo.asset}
                    full
                    className="text-sm text-on-surface/90"
                  />
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-on-surface-variant mb-1">Total Assets</p>
                    <p className="text-lg font-semibold text-on-surface tabular-nums">
                      {formatDecimalOutput(fleetInfo.totalAssets, assetInfo.decimals)}{' '}
                      {assetInfo.symbol}
                    </p>
                  </div>

                  <div>
                    <p className="text-sm text-on-surface-variant mb-1">Withdrawable</p>
                    <p className="text-lg font-semibold text-on-surface tabular-nums">
                      {formatDecimalOutput(fleetInfo.withdrawableTotalAssets, assetInfo.decimals)}{' '}
                      {assetInfo.symbol}
                    </p>
                  </div>
                </div>

                {fleetInfo.depositCap > BigInt(0) && (
                  <div>
                    <div className="flex justify-between text-sm mb-2">
                      <span className="text-on-surface-variant">Deposit Cap</span>
                      <span className="text-on-surface tabular-nums">
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
              <h3 className="text-lg font-headline font-semibold text-on-surface mb-6">
                Your Position
              </h3>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-on-surface-variant mb-1">Your Fleet Tokens</p>
                  <p className="text-lg font-semibold text-on-surface tabular-nums">
                    {formatDecimalOutput(userInfo.balance, fleetInfo.fleetDecimals)}{' '}
                    {fleetInfo.symbol}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-on-surface-variant mb-1">
                    Your {assetInfo.symbol} Balance
                  </p>
                  <p className="text-lg font-semibold text-on-surface tabular-nums">
                    {formatDecimalOutput(userInfo.underlyingBalance, assetInfo.decimals)}{' '}
                    {assetInfo.symbol}
                  </p>
                </div>
              </div>
            </GlassCard>
          )}

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
            <h2 className="text-lg font-headline font-semibold text-on-surface mb-6">
              Active Fleet Arks
            </h2>

            {arksLoading ? (
              <div className="text-center text-on-surface-variant">Loading arks...</div>
            ) : arks.length === 0 ? (
              <div className="text-center text-on-surface-variant">
                No arks found for this fleet.
              </div>
            ) : (
              <div className="space-y-4">
                {arks.map((ark) => (
                  <div key={ark.address} className="glass rounded-xl p-4">
                    <div className="flex justify-between items-start mb-2">
                      <div>
                        <div className="flex items-center gap-2 mb-1">
                          <h4 className="text-on-surface font-semibold">{ark.name}</h4>
                          {ark.isBufferArk && <Badge tone="primary">Buffer Ark</Badge>}
                          {ark.hasWithdrawalQueue && <Badge tone="info">Withdrawal Queue</Badge>}
                          {ark.needsSweep && !ark.isBufferArk && (
                            <Badge tone="warning">Needs Sweep</Badge>
                          )}
                        </div>
                        {ark.withdrawalRequestId != null && (
                          <p className="text-xs text-on-surface-variant mt-0.5">
                            Withdrawal ID: {ark.withdrawalRequestId}
                          </p>
                        )}
                        <AddressDisplay
                          value={ark.address}
                          chars={8}
                          className="text-sm text-on-surface-variant"
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4 text-sm mb-4">
                      <div>
                        <p className="text-on-surface-variant">Balance</p>
                        <p className="text-on-surface font-medium tabular-nums">
                          {formatDecimalOutput(ark.totalAssets, assetInfo.decimals)}{' '}
                          {assetInfo.symbol}
                        </p>
                      </div>
                      <div>
                        <p className="text-on-surface-variant">Allocation</p>
                        <p className="text-on-surface font-medium tabular-nums">
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
                      <p className="text-xs text-on-surface-variant mb-3 font-semibold uppercase tracking-wide">
                        Config Limits
                      </p>
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                          <p className="text-on-surface-variant">Deposit Cap</p>
                          <p className="text-on-surface font-medium tabular-nums">
                            {ark.depositCap === BigInt(0)
                              ? 'Zero'
                              : `${formatDecimalOutput(ark.depositCap, assetInfo.decimals)} ${assetInfo.symbol}`}
                          </p>
                          {ark.depositCap > BigInt(0) && (
                            <p className="text-xs text-on-surface-variant mt-1">
                              {formatPercentage(
                                (ark.totalAssets * BigInt(100) * BigInt(10 ** 18)) / ark.depositCap,
                              )}{' '}
                              of cap used
                            </p>
                          )}
                        </div>
                        <div>
                          <p className="text-on-surface-variant">Max Deposit % of TVL</p>
                          <p className="text-on-surface font-medium tabular-nums">
                            {ark.maxDepositPercentageOfTVL === BigInt(0)
                              ? 'Zero'
                              : formatPercentage(ark.maxDepositPercentageOfTVL)}
                          </p>
                          {fleetInfo &&
                            fleetInfo.totalAssets > BigInt(0) &&
                            ark.totalAssets > BigInt(0) && (
                              <p className="text-xs text-on-surface-variant mt-1">
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
                          <p className="text-on-surface-variant">Max Rebalance Inflow</p>
                          <p className="text-on-surface font-medium tabular-nums">
                            {ark.maxRebalanceInflow ===
                            BigInt(
                              '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
                            )
                              ? 'Unlimited'
                              : `${formatDecimalOutput(ark.maxRebalanceInflow, assetInfo.decimals)} ${assetInfo.symbol}`}
                          </p>
                        </div>
                        <div>
                          <p className="text-on-surface-variant">Max Rebalance Outflow</p>
                          <p className="text-on-surface font-medium tabular-nums">
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
                      pendingDepositAssets={ark.pendingDepositAssets}
                      sharesToAssets1e18={ark.sharesToAssets1e18}
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
              className="w-full flex items-center justify-between text-on-surface py-3 px-1 rounded-md hover:bg-white/5 transition-colors"
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
