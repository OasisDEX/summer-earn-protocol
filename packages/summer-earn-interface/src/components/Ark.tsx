import { useState } from 'react'
import { Address, parseUnits } from 'viem'
import { useChainId } from 'wagmi'

import { ChainId } from '@/types'

import { useRaftContract } from '../contracts/Raft'
import { useArkWithdrawalActions } from '../hooks/useArkWithdrawalActions'
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
    <div className="bg-gray-400 shadow rounded-lg p-6 mb-4">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-xl font-bold">{name}</h2>
      </div>

      {/* Auction Controls Section - Foldable */}
      <div className="mb-4">
        <button
          onClick={() => setIsAuctionControlsOpen(!isAuctionControlsOpen)}
          className="w-full flex items-center justify-between bg-gray-500 text-white py-2 px-4 rounded-md hover:bg-gray-600 mb-2"
        >
          <span className="font-semibold">Auction Controls</span>
          <span
            className={`transform transition-transform ${isAuctionControlsOpen ? 'rotate-180' : ''}`}
          >
            ▼
          </span>
        </button>

        {isAuctionControlsOpen && (
          <div className="bg-gray-300 p-4 rounded-md space-y-3">
            <div className="flex space-x-2">
              <button
                onClick={handleHarvest}
                className="flex-1 bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700"
              >
                Harvest
              </button>
              <button
                onClick={handleHarvestAndStartAuction}
                className="flex-1 bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700"
              >
                Harvest & Start Auction
              </button>
              <button
                onClick={() => setIsConfigModalOpen(true)}
                className="flex-1 bg-purple-600 text-white py-2 px-4 rounded-md hover:bg-purple-700"
              >
                Configure Auction
              </button>
            </div>

            <button
              onClick={handleFetchObtainedTokens}
              disabled={isLoadingTokens}
              className="w-full bg-yellow-600 text-white py-2 px-4 rounded-md hover:bg-yellow-700 disabled:opacity-50"
            >
              {isLoadingTokens ? 'Loading...' : 'Fetch Obtained Tokens'}
            </button>

            {obtainedTokens.length > 0 && (
              <div className="mt-4">
                <h3 className="text-lg font-semibold mb-2">Obtained Tokens:</h3>
                <div className="space-y-2">
                  {obtainedTokens.map((token) => (
                    <div key={token.tokenAddress} className="bg-gray-500 p-3 rounded">
                      <p className="text-sm">Token: {token.tokenAddress}</p>
                      <p className="text-sm">Amount: {token.amount.toString()}</p>
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
            className="w-full flex items-center justify-between bg-gray-500 text-white py-2 px-4 rounded-md hover:bg-gray-600 mb-2"
          >
            <span className="font-semibold">Withdrawal Queue</span>
            <span
              className={`transform transition-transform ${isWithdrawalQueueOpen ? 'rotate-180' : ''}`}
            >
              ▼
            </span>
          </button>

          {isWithdrawalQueueOpen && (
            <div className="bg-gray-300 p-4 rounded-md space-y-4">
              {withdrawalRequestId != null && (
                <div>
                  <p className="text-sm text-gray-600">Withdrawal Request ID</p>
                  <p className="font-mono text-sm">{withdrawalRequestId}</p>
                </div>
              )}
              {assetsInWithdrawalQueue != null && BigInt(assetsInWithdrawalQueue) > BigInt(0) && (
                <div>
                  <p className="text-sm text-gray-600">Assets in Queue</p>
                  <p className="font-medium">
                    {formatDecimalOutput(BigInt(assetsInWithdrawalQueue), assetDecimals)}{' '}
                    {assetSymbol}
                  </p>
                </div>
              )}
              {assetBalance != null && (
                <div>
                  <p className="text-sm text-gray-600">Ark Asset Balance (sweepable)</p>
                  <p className="font-medium">
                    {formatDecimalOutput(BigInt(assetBalance), assetDecimals)} {assetSymbol}
                  </p>
                  {needsSweep && !isBufferArk && (
                    <p className="text-xs text-amber-600 font-medium mt-1">Needs sweep</p>
                  )}
                </div>
              )}

              <div className="flex flex-wrap gap-2 items-end">
                <div>
                  <label className="block text-xs text-gray-600 mb-1">Request amount</label>
                  <input
                    type="text"
                    placeholder="0"
                    value={requestWithdrawalAmount}
                    onChange={(e) => setRequestWithdrawalAmount(e.target.value)}
                    className="w-32 px-2 py-1 border border-gray-500 rounded text-sm"
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
                  className="bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 disabled:opacity-50 text-sm"
                >
                  Request Withdrawal
                </button>
                {isWithdrawalClaimRequired && (
                  <button
                    onClick={() => claimWithdrawal()}
                    disabled={isWithdrawalActionPending}
                    className="bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 disabled:opacity-50 text-sm"
                  >
                    Claim Withdrawal
                  </button>
                )}
                <button
                  onClick={() => sweep()}
                  disabled={isWithdrawalActionPending}
                  className="bg-amber-600 text-white py-2 px-4 rounded-md hover:bg-amber-700 disabled:opacity-50 text-sm"
                >
                  Sweep
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Ark Management Section - Foldable */}
      <div className="mb-4">
        <button
          onClick={() => setIsArkManagementOpen(!isArkManagementOpen)}
          className="w-full flex items-center justify-between bg-gray-500 text-white py-2 px-4 rounded-md hover:bg-gray-600 mb-2"
        >
          <span className="font-semibold">Ark Management</span>
          <span
            className={`transform transition-transform ${isArkManagementOpen ? 'rotate-180' : ''}`}
          >
            ▼
          </span>
        </button>

        {isArkManagementOpen && (
          <div className="bg-gray-300 p-4 rounded-md">
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
