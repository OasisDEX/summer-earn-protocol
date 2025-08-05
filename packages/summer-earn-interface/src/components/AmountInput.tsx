'use client'

import { useState, useEffect } from 'react'
import { formatDecimalOutput, parseDecimalInput, MAX_UINT256 } from '../utils/decimals'

interface AmountInputProps {
  value: string
  onChange: (value: string, parsed: bigint) => void
  placeholder?: string
  symbol: string
  decimals: number
  balance?: bigint
  showMaxButton?: boolean
  showMaxUintButton?: boolean
  label?: string
  disabled?: boolean
  className?: string
}

export function AmountInput({
  value,
  onChange,
  placeholder,
  symbol,
  decimals,
  balance,
  showMaxButton = false,
  showMaxUintButton = false,
  label,
  disabled = false,
  className = '',
}: AmountInputProps) {
  const [displayValue, setDisplayValue] = useState(value)

  useEffect(() => {
    setDisplayValue(value)
  }, [value])

  const handleInputChange = (inputValue: string) => {
    // Allow empty string
    if (inputValue === '') {
      setDisplayValue('')
      onChange('', BigInt(0))
      return
    }

    // Basic validation for decimal input
    const decimalRegex = /^\d*\.?\d*$/
    if (!decimalRegex.test(inputValue)) {
      return // Don't update if invalid format
    }

    setDisplayValue(inputValue)
    const parsed = parseDecimalInput(inputValue, decimals)
    onChange(inputValue, parsed)
  }

  const handleMaxClick = () => {
    if (!balance) return
    const maxValue = formatDecimalOutput(balance, decimals, 8)
    setDisplayValue(maxValue)
    onChange(maxValue, balance)
  }

  const handleMaxUintClick = () => {
    const maxValue = 'MAX'
    setDisplayValue(maxValue)
    onChange(maxValue, MAX_UINT256)
  }

  return (
    <div className={`space-y-2 ${className}`}>
      {label && (
        <label className="block text-sm font-medium text-gray-300">
          {label}
        </label>
      )}
      
      <div className="relative">
        <input
          type="text"
          value={displayValue}
          onChange={(e) => handleInputChange(e.target.value)}
          placeholder={placeholder || `Amount in ${symbol}`}
          disabled={disabled}
          className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent pr-16"
        />
        
        <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 text-sm">
          {symbol}
        </div>
      </div>

      {/* Action buttons */}
      <div className="flex gap-2">
        {showMaxButton && balance && balance > BigInt(0) && (
          <button
            type="button"
            onClick={handleMaxClick}
            className="px-3 py-1 text-xs bg-gray-700 hover:bg-gray-600 text-gray-300 rounded-md transition-colors"
          >
            Max Balance ({formatDecimalOutput(balance, decimals, 4)} {symbol})
          </button>
        )}
        
        {showMaxUintButton && (
          <button
            type="button"
            onClick={handleMaxUintClick}
            className="px-3 py-1 text-xs bg-red-700 hover:bg-red-600 text-red-200 rounded-md transition-colors"
          >
            Max Uint (Unlimited)
          </button>
        )}
      </div>

      {/* Balance display */}
      {balance && (
        <div className="text-sm text-gray-400">
          Available: {formatDecimalOutput(balance, decimals)} {symbol}
        </div>
      )}
    </div>
  )
}