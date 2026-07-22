import { useState } from 'react'
import { Address } from 'viem'
import { useChainId } from 'wagmi'

import { BaseAuctionParameters, useRaftContract } from '../contracts/Raft'
import { Button, inputBase, labelBase } from './ui'
import { Modal } from './ui/Modal'

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
    <Modal onClose={onClose} title="Configure Auction Parameters" size="sm">
      <form onSubmit={handleSubmit}>
        <div className="mb-4">
          <label className={labelBase}>Duration (seconds)</label>
          <input
            type="number"
            value={duration}
            onChange={(e) => setDuration(e.target.value)}
            className={inputBase}
            required
          />
        </div>
        <div className="mb-4">
          <label className={labelBase}>Start Price</label>
          <input
            type="number"
            value={startPrice}
            onChange={(e) => setStartPrice(e.target.value)}
            className={inputBase}
            required
          />
        </div>
        <div className="mb-4">
          <label className={labelBase}>End Price</label>
          <input
            type="number"
            value={endPrice}
            onChange={(e) => setEndPrice(e.target.value)}
            className={inputBase}
            required
          />
        </div>
        <div className="flex justify-end gap-2">
          <Button type="button" onClick={onClose} variant="ghost">
            Cancel
          </Button>
          <Button type="submit" variant="primary">
            Save
          </Button>
        </div>
      </form>
    </Modal>
  )
}
