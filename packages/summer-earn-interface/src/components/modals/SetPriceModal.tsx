'use client'

import { useState } from 'react'

import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'
import { Button, helpTextBase, inputBase, labelBase } from '../ui'
import { Modal } from '../ui/Modal'

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
    <Modal onClose={onClose} title="Set Token Price" size="md">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Token Address */}
        <div>
          <label className={labelBase}>Token Address</label>
          <input
            type="text"
            value={formData.token}
            onChange={(e) => handleInputChange('token', e.target.value)}
            placeholder="0x..."
            className={inputBase}
            required
          />
        </div>

        {/* Price */}
        <div>
          <label className={labelBase}>Price (USD)</label>
          <input
            type="number"
            step="0.000001"
            value={formData.price}
            onChange={(e) => handleInputChange('price', e.target.value)}
            placeholder="1.00"
            className={inputBase}
            required
          />
          <div className={helpTextBase}>
            USD price (e.g., enter &quot;1.00&quot; for $1.00 USD - will be converted to 18 decimals
            automatically)
          </div>
        </div>

        {/* Decimals */}
        <div>
          <label className={labelBase}>Token Decimals</label>
          <input
            type="number"
            value={formData.decimals}
            onChange={(e) => handleInputChange('decimals', e.target.value)}
            placeholder="6"
            min="0"
            max="18"
            className={inputBase}
            required
          />
          <div className={helpTextBase}>
            Token&apos;s native decimal places (USDC = 6, SUMMER = 18)
          </div>
        </div>

        {/* Error Display */}
        {error && (
          <div className="text-error text-sm bg-error/15 border border-error/30 p-3 rounded-lg">
            {error}
          </div>
        )}

        {/* Submit Button */}
        <Button type="submit" disabled={loading} variant="primary" fullWidth>
          {loading ? 'Setting Price...' : 'Set Price'}
        </Button>
      </form>

      <div className="mt-4 text-xs text-on-surface-variant">
        <p>• This updates the price in the MockIntentOracle</p>
        <p>• Price will be set with 18 decimal places for USD</p>
        <p>• Only works with the mock oracle (testing environment)</p>
      </div>
    </Modal>
  )
}
