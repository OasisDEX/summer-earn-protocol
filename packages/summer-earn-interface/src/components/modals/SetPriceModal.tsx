'use client'

import { useState } from 'react'

import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'

interface SetPriceModalProps {
  isOpen: boolean
  onClose: () => void
  environment: Environment
  chainId: ChainId
}

const USD_MULTIPLIER = BigInt(10 ** 18)

export function SetPriceModal({ isOpen, onClose, environment, chainId }: SetPriceModalProps) {
  const { setPrice, loading, error, tokens } = useIntentSystem(environment, chainId)

  const [formData, setFormData] = useState({
    token: tokens?.USDC || '',
    price: '', // USD price (will be converted to 18 decimals)
    decimals: '6', // Token decimals
  })

  const handleInputChange = (field: string, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      // Validate inputs
      if (!formData.token || formData.token === '') {
        alert('Please enter a token address')
        return
      }
      if (!formData.price || formData.price === '') {
        alert('Please enter a price')
        return
      }
      if (!formData.decimals || formData.decimals === '') {
        alert('Please enter token decimals')
        return
      }

      // Convert price to 18 decimal format
      const priceInWei = BigInt(formData.price) * USD_MULTIPLIER
      const decimals = parseInt(formData.decimals)

      console.log('Setting price:', {
        token: formData.token,
        price: formData.price,
        priceInWei: priceInWei.toString(),
        decimals: decimals,
      })

      const hash = await setPrice(formData.token, priceInWei, decimals)

      console.log('Price set successfully:', hash)
      onClose()

      // Reset form
      setFormData({
        token: tokens?.USDC || '',
        price: '',
        decimals: '6',
      })
    } catch (err) {
      console.error('Error setting price:', err)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-gray-800 rounded-lg p-6 w-full max-w-md mx-4">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-white">Set Token Price</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Token Address */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Token Address</label>
            <input
              type="text"
              value={formData.token}
              onChange={(e) => handleInputChange('token', e.target.value)}
              placeholder="0x..."
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Price */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Price (USD)</label>
            <input
              type="number"
              step="0.000001"
              value={formData.price}
              onChange={(e) => handleInputChange('price', e.target.value)}
              placeholder="1.00"
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
            <div className="text-xs text-gray-400 mt-1">
              USD price (e.g., enter &quot;1.00&quot; for $1.00 USD - will be converted to 18
              decimals automatically)
            </div>
          </div>

          {/* Decimals */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Token Decimals</label>
            <input
              type="number"
              value={formData.decimals}
              onChange={(e) => handleInputChange('decimals', e.target.value)}
              placeholder="6"
              min="0"
              max="18"
              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
            <div className="text-xs text-gray-400 mt-1">
              Token&apos;s native decimal places (USDC = 6, SUMMER = 18)
            </div>
          </div>

          {/* Error Display */}
          {error && (
            <div className="text-red-400 text-sm bg-red-900/20 p-3 rounded-lg">{error}</div>
          )}

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-yellow-600 hover:bg-yellow-700 disabled:bg-gray-600 text-white rounded-lg font-medium transition-colors"
          >
            {loading ? 'Setting Price...' : 'Set Price'}
          </button>
        </form>

        <div className="mt-4 text-xs text-gray-400">
          <p>• This updates the price in the MockIntentOracle</p>
          <p>• Price will be set with 18 decimal places for USD</p>
          <p>• Only works with the mock oracle (testing environment)</p>
        </div>
      </div>
    </div>
  )
}
