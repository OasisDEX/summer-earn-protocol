import { useState } from 'react'
import { Address, parseUnits } from 'viem'
import { useChainId } from 'wagmi'

import { ChainId } from '@/types'

import { useRaftContract } from '../contracts/Raft'
import { useArkWithdrawalActions } from '../hooks/useArkWithdrawalActions'
import { useWisdomTreeActions } from '../hooks/useWisdomTreeActions'
import { useWisdomTreeSharesToAssets } from '../hooks/useWisdomTreeSharesToAssets'
import { formatDecimalOutput } from '../utils/decimals'
import { ArkManagementForm } from './ArkManagementForm'
import { AuctionConfigModal } from './AuctionConfigModal'

interface ArkProps {
  arkAddress: Address
  rewardToken: Address
  name: string
  fleetAddress: Address
  assetDecimals: number
  assetSymbol: string
  isBufferArk?: boolean
  /** IArkWithWithdrawalRequest: withdrawal queue data */
  hasWithdrawalQueue?: boolean
  withdrawalRequestId?: string
  assetsInWithdrawalQueue?: string
  isWithdrawalClaimRequired?: boolean
  assetBalance?: string
  needsSweep?: boolean
  pendingDepositAssets?: string
  sharesToAssets1e18?: string
  /** Called after successful withdrawal action (for refetch) */
  onWithdrawalSuccess?: () => void
}

interface ObtainedToken {
  tokenAddress: string
  amount: bigint
}

export function Ark({
  arkAddress,
  rewardToken,
  name,
  fleetAddress,
  assetDecimals,
  assetSymbol,
  isBufferArk,
  hasWithdrawalQueue,
  withdrawalRequestId,
  assetsInWithdrawalQueue,
  isWithdrawalClaimRequired,
  assetBalance,
  needsSweep,
  pendingDepositAssets,
  sharesToAssets1e18,
  onWithdrawalSuccess,
}: ArkProps) {
  const [isConfigModalOpen, setIsConfigModalOpen] = useState(false)
  const [obtainedTokens, setObtainedTokens] = useState<ObtainedToken[]>([])
  const [isLoadingTokens, setIsLoadingTokens] = useState(false)
  const [isAuctionControlsOpen, setIsAuctionControlsOpen] = useState(false)
  const [isArkManagementOpen, setIsArkManagementOpen] = useState(false)
  const [isWithdrawalQueueOpen, setIsWithdrawalQueueOpen] = useState(false)
  const [requestWithdrawalAmount, setRequestWithdrawalAmount] = useState('')
  const { harvest, harvestAndStartAuction, getObtainedTokens } = useRaftContract()
  const chainId = useChainId()
  const {
    requestWithdrawal,
    claimWithdrawal,
    sweep,
    isPending: isWithdrawalActionPending,
  } = useArkWithdrawalActions({
    arkAddress,
    chainId: chainId.toString() as ChainId,
    onSuccess: onWithdrawalSuccess,
  })

  // WisdomTree specific
  const isWisdomTree = name.toLowerCase().includes('wisdomtree')
  const [isWisdomTreeControlsOpen, setIsWisdomTreeControlsOpen] = useState(false)
  const [sharesQueryInput, setSharesQueryInput] = useState('1')

  const { clearPendingDeposit, isPending: isClearPending } = useWisdomTreeActions({
    arkAddress,
    chainId: chainId.toString() as ChainId,
    onSuccess: onWithdrawalSuccess,
  })

  const { assets: queriedAssets, isLoading: isQueryingShares } = useWisdomTreeSharesToAssets({
    arkAddress,
    chainId: chainId.toString() as ChainId,
    shares: (() => {
      try {
        // Assume WisdomTree shares have 18 decimals like standard WAD
        return parseUnits(sharesQueryInput || '0', 18)
      } catch {
        return 0n
      }
    })(),
    enabled: isWisdomTree && isWisdomTreeControlsOpen && Boolean(sharesQueryInput),
  })

  const handleHarvest = async () => {
    try {
      await harvest(arkAddress, chainId)
    } catch (error) {
      console.error('Failed to harvest:', error)
    }
  }

  const handleHarvestAndStartAuction = async () => {
    try {
      await harvestAndStartAuction(arkAddress, chainId)
    } catch (error) {
      console.error('Failed to harvest and start auction:', error)
    }
  }

  const handleFetchObtainedTokens = async () => {
    try {
      setIsLoadingTokens(true)
      const tokens = await getObtainedTokens(arkAddress, chainId)
      setObtainedTokens(tokens)
    } catch (error) {
      console.error('Failed to fetch obtained tokens:', error)
    } finally {
      setIsLoadingTokens(false)
    }
  }

  return (
    <div className="bg-white/[0.03] border border-white/5 rounded-lg p-4 mt-4">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-base font-semibold text-on-surface">
          {name}
          {isWisdomTree && (
            <span className="ml-2 px-2 py-0.5 bg-info/15 text-info text-xs font-medium rounded-full align-middle">
              WisdomTree
            </span>
          )}
        </h2>
      </div>

      {/* Auction Controls Section - Foldable */}
      <div className="mb-4">
        <button
          onClick={() => setIsAuctionControlsOpen(!isAuctionControlsOpen)}
          className="w-full flex items-center justify-between bg-white/5 border border-white/10 text-on-surface py-2 px-4 rounded-md hover:bg-white/10 transition-colors mb-2"
        >
          <span className="font-semibold">Auction Controls</span>
          <span
            className={`transform transition-transform ${isAuctionControlsOpen ? 'rotate-180' : ''}`}
          >
            ▼
          </span>
        </button>

        {isAuctionControlsOpen && (
          <div className="bg-black/20 border border-white/5 p-4 rounded-md space-y-3">
            <div className="flex space-x-2">
              <button
                onClick={handleHarvest}
                className="flex-1 bg-primary text-on-primary font-semibold py-2 px-4 rounded-md hover:bg-primary-dim transition-colors"
              >
                Harvest
              </button>
              <button
                onClick={handleHarvestAndStartAuction}
                className="flex-1 bg-secondary/15 border border-secondary/30 text-secondary font-semibold py-2 px-4 rounded-md hover:bg-secondary/25 transition-colors"
              >
                Harvest & Start Auction
              </button>
              <button
                onClick={() => setIsConfigModalOpen(true)}
                className="flex-1 bg-white/5 border border-white/10 text-on-surface font-semibold py-2 px-4 rounded-md hover:bg-white/10 transition-colors"
              >
                Configure Auction
              </button>
            </div>

            <button
              onClick={handleFetchObtainedTokens}
              disabled={isLoadingTokens}
              className="w-full bg-white/5 border border-white/10 text-on-surface py-2 px-4 rounded-md hover:bg-white/10 disabled:opacity-40 transition-colors"
            >
              {isLoadingTokens ? 'Loading...' : 'Fetch Obtained Tokens'}
            </button>

            {obtainedTokens.length > 0 && (
              <div className="mt-4">
                <h3 className="text-sm font-semibold text-on-surface mb-2">Obtained Tokens</h3>
                <div className="space-y-2">
                  {obtainedTokens.map((token) => (
                    <div
                      key={token.tokenAddress}
                      className="bg-white/5 border border-white/10 p-3 rounded"
                    >
                      <p className="text-sm font-mono break-all text-on-surface-variant">
                        Token: {token.tokenAddress}
                      </p>
                      <p className="text-sm tabular-nums text-on-surface">
                        Amount: {token.amount.toString()}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Withdrawal Queue Section - Foldable, only for IArkWithWithdrawalRequest arks */}
      {hasWithdrawalQueue && (
        <div className="mb-4">
          <button
            onClick={() => setIsWithdrawalQueueOpen(!isWithdrawalQueueOpen)}
            className="w-full flex items-center justify-between bg-white/5 border border-white/10 text-on-surface py-2 px-4 rounded-md hover:bg-white/10 transition-colors mb-2"
          >
            <span className="font-semibold">Withdrawal Queue</span>
            <span
              className={`transform transition-transform ${isWithdrawalQueueOpen ? 'rotate-180' : ''}`}
            >
              ▼
            </span>
          </button>

          {isWithdrawalQueueOpen && (
            <div className="bg-black/20 border border-white/5 p-4 rounded-md space-y-4">
              {withdrawalRequestId != null && (
                <div>
                  <p className="text-sm text-on-surface-variant">Withdrawal Request ID</p>
                  <p className="font-mono text-sm text-on-surface break-all">
                    {withdrawalRequestId}
                  </p>
                </div>
              )}
              {assetsInWithdrawalQueue != null && BigInt(assetsInWithdrawalQueue) > BigInt(0) && (
                <div>
                  <p className="text-sm text-on-surface-variant">Assets in Queue</p>
                  <p className="font-medium text-on-surface tabular-nums">
                    {formatDecimalOutput(BigInt(assetsInWithdrawalQueue), assetDecimals)}{' '}
                    {assetSymbol}
                  </p>
                </div>
              )}
              {assetBalance != null && (
                <div>
                  <p className="text-sm text-on-surface-variant">Ark Asset Balance (sweepable)</p>
                  <p className="font-medium text-on-surface tabular-nums">
                    {formatDecimalOutput(BigInt(assetBalance), assetDecimals)} {assetSymbol}
                  </p>
                  {needsSweep && !isBufferArk && (
                    <p className="text-xs text-warning font-medium mt-1">Needs sweep</p>
                  )}
                </div>
              )}

              <div className="flex flex-wrap gap-2 items-end">
                <div>
                  <label className="block text-xs text-on-surface-variant mb-1">
                    Request amount
                  </label>
                  <input
                    type="text"
                    placeholder="0"
                    value={requestWithdrawalAmount}
                    onChange={(e) => setRequestWithdrawalAmount(e.target.value)}
                    className="w-32 px-2 py-1 bg-surface-container border border-white/10 rounded text-sm text-on-surface tabular-nums focus:outline-none focus:border-primary/60"
                  />
                </div>
                <button
                  onClick={() => {
                    try {
                      const amount = parseUnits(requestWithdrawalAmount || '0', assetDecimals)
                      if (amount > BigInt(0)) {
                        requestWithdrawal(amount)
                      }
                    } catch {
                      // invalid input, ignore
                    }
                  }}
                  disabled={isWithdrawalActionPending}
                  className="bg-primary text-on-primary font-semibold py-2 px-4 rounded-md hover:bg-primary-dim disabled:opacity-40 text-sm transition-colors"
                >
                  Request Withdrawal
                </button>
                {isWithdrawalClaimRequired && (
                  <button
                    onClick={() => claimWithdrawal()}
                    disabled={isWithdrawalActionPending}
                    className="bg-secondary/15 border border-secondary/30 text-secondary font-semibold py-2 px-4 rounded-md hover:bg-secondary/25 disabled:opacity-40 text-sm transition-colors"
                  >
                    Claim Withdrawal
                  </button>
                )}
                <button
                  onClick={() => sweep()}
                  disabled={isWithdrawalActionPending}
                  className="bg-warning/15 border border-warning/30 text-warning font-semibold py-2 px-4 rounded-md hover:bg-warning/25 disabled:opacity-40 text-sm transition-colors"
                >
                  Sweep
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* WisdomTree Controls Section - Foldable */}
      {isWisdomTree && (
        <div className="mb-4">
          <button
            onClick={() => setIsWisdomTreeControlsOpen(!isWisdomTreeControlsOpen)}
            className="w-full flex items-center justify-between bg-info/10 border border-info/20 text-info py-2 px-4 rounded-md hover:bg-info/20 transition-colors mb-2"
          >
            <span className="font-semibold">WisdomTree Controls</span>
            <span
              className={`transform transition-transform ${isWisdomTreeControlsOpen ? 'rotate-180' : ''}`}
            >
              ▼
            </span>
          </button>

          {isWisdomTreeControlsOpen && (
            <div className="bg-info/5 border border-info/15 p-4 rounded-md space-y-4">
              {pendingDepositAssets != null && (
                <div>
                  <p className="text-sm text-info font-semibold mb-1">Pending Deposit Assets</p>
                  <p className="font-medium text-on-surface tabular-nums border border-white/10 rounded px-2 py-1 bg-black/20 inline-block">
                    {formatDecimalOutput(BigInt(pendingDepositAssets), assetDecimals)} {assetSymbol}
                  </p>
                  {BigInt(pendingDepositAssets) > 0n && (
                    <button
                      onClick={() => clearPendingDeposit()}
                      disabled={isClearPending}
                      className="ml-3 bg-error/15 border border-error/30 text-error py-1 px-3 rounded text-sm hover:bg-error/25 disabled:opacity-40 transition-colors"
                    >
                      {isClearPending ? 'Clearing...' : 'Clear Pending Deposit'}
                    </button>
                  )}
                </div>
              )}

              {sharesToAssets1e18 != null && (
                <div className="pt-2 border-t border-white/10">
                  <p className="text-sm text-info font-semibold mb-1">
                    Default Share Price (1 share)
                  </p>
                  <p className="font-medium text-on-surface tabular-nums">
                    {formatDecimalOutput(BigInt(sharesToAssets1e18), assetDecimals)} {assetSymbol}
                  </p>
                </div>
              )}

              <div className="pt-2 border-t border-white/10">
                <p className="text-sm text-info font-semibold mb-2">Convert Shares to Assets</p>
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    min="0"
                    step="0.0001"
                    placeholder="E.g. 1.5"
                    value={sharesQueryInput}
                    onChange={(e) => setSharesQueryInput(e.target.value)}
                    className="w-32 px-2 py-1.5 bg-surface-container border border-white/10 rounded text-sm text-on-surface tabular-nums focus:outline-none focus:border-primary/60"
                  />
                  <span className="text-sm text-on-surface-variant">shares =</span>
                  <div className="px-3 py-1.5 bg-black/20 border border-white/10 rounded text-sm font-medium min-w-[100px] text-on-surface tabular-nums flex items-center justify-center">
                    {isQueryingShares ? (
                      <span className="animate-pulse">Loading...</span>
                    ) : queriedAssets !== undefined ? (
                      `${formatDecimalOutput(queriedAssets as bigint, assetDecimals)} ${assetSymbol}`
                    ) : (
                      '-'
                    )}
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Ark Management Section - Foldable */}
      <div className="mb-4">
        <button
          onClick={() => setIsArkManagementOpen(!isArkManagementOpen)}
          className="w-full flex items-center justify-between bg-white/5 border border-white/10 text-on-surface py-2 px-4 rounded-md hover:bg-white/10 transition-colors mb-2"
        >
          <span className="font-semibold">Ark Management</span>
          <span
            className={`transform transition-transform ${isArkManagementOpen ? 'rotate-180' : ''}`}
          >
            ▼
          </span>
        </button>

        {isArkManagementOpen && (
          <div className="bg-black/20 border border-white/5 p-4 rounded-md">
            <ArkManagementForm
              arkAddress={arkAddress}
              fleetAddress={fleetAddress}
              chainId={chainId.toString() as ChainId}
              assetDecimals={assetDecimals}
              assetSymbol={assetSymbol}
            />
          </div>
        )}
      </div>

      <AuctionConfigModal
        isOpen={isConfigModalOpen}
        onClose={() => setIsConfigModalOpen(false)}
        arkAddress={arkAddress}
        rewardToken={rewardToken}
      />
    </div>
  )
}
