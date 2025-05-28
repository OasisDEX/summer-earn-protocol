import { useState } from 'react'
import { Address } from 'viem'
import { useChainId } from 'wagmi'
import { useRaftContract } from '../contracts/Raft'
import { AuctionConfigModal } from './AuctionConfigModal'

interface ArkProps {
  arkAddress: Address
  rewardToken: Address
  name: string
}

interface ObtainedToken {
  tokenAddress: string
  amount: bigint
}

export function Ark({ arkAddress, rewardToken, name }: ArkProps) {
  const [isConfigModalOpen, setIsConfigModalOpen] = useState(false)
  const [obtainedTokens, setObtainedTokens] = useState<ObtainedToken[]>([])
  const [isLoadingTokens, setIsLoadingTokens] = useState(false)
  const { harvest, harvestAndStartAuction, getObtainedTokens } = useRaftContract()
  const chainId = useChainId()

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

      <div className="flex space-x-2 mb-4">
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

      <div className="mt-4">
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

      <AuctionConfigModal
        isOpen={isConfigModalOpen}
        onClose={() => setIsConfigModalOpen(false)}
        arkAddress={arkAddress}
        rewardToken={rewardToken}
      />
    </div>
  )
}
