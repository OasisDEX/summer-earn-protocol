import { useState } from 'react'
import { Address } from 'viem'
import { useChainId } from 'wagmi'

import { BaseAuctionParameters, useRaftContract } from '../contracts/Raft'

interface AuctionConfigModalProps {
  isOpen: boolean
  onClose: () => void
  arkAddress: Address
  rewardToken: Address
}

export function AuctionConfigModal({
  isOpen,
  onClose,
  arkAddress,
  rewardToken,
}: AuctionConfigModalProps) {
  const [duration, setDuration] = useState('')
  const [startPrice, setStartPrice] = useState('')
  const [endPrice, setEndPrice] = useState('')
  const { setAuctionParameters } = useRaftContract()
  const chainId = useChainId()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    const parameters: BaseAuctionParameters = {
      duration: parseInt(duration),
      startPrice: BigInt(startPrice),
      endPrice: BigInt(endPrice),
      kickerRewardPercentage: BigInt(0),
      decayType: 0,
    }

    try {
      await setAuctionParameters(arkAddress, rewardToken, parameters, chainId)
      onClose()
    } catch (error) {
      console.error('Failed to set auction parameters:', error)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-gray-900 border border-gray-800 p-6 rounded-lg w-96 text-white">
        <h2 className="text-xl font-bold mb-4">Configure Auction Parameters</h2>
        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label className="block text-sm font-medium mb-1">Duration (seconds)</label>
            <input
              type="number"
              value={duration}
              onChange={(e) => setDuration(e.target.value)}
              className="w-full p-2 border rounded"
              required
            />
          </div>
          <div className="mb-4">
            <label className="block text-sm font-medium mb-1">Start Price</label>
            <input
              type="number"
              value={startPrice}
              onChange={(e) => setStartPrice(e.target.value)}
              className="w-full p-2 border rounded"
              required
            />
          </div>
          <div className="mb-4">
            <label className="block text-sm font-medium mb-1">End Price</label>
            <input
              type="number"
              value={endPrice}
              onChange={(e) => setEndPrice(e.target.value)}
              className="w-full p-2 border rounded"
              required
            />
          </div>
          <div className="flex justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-gray-600 hover:text-gray-800"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              Save
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
