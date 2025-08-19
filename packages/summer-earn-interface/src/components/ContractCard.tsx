'use client'

import { useState } from 'react'

interface ContractCardProps {
  title: string
  description: string
  address: string
  icon: string
  color: string
  chainId: string
  onCopy?: (address: string) => void
  copiedAddress?: string | null
}

export function ContractCard({
  title,
  description,
  address,
  icon,
  color,
  chainId,
  onCopy,
  copiedAddress,
}: ContractCardProps) {
  const [isExpanded, setIsExpanded] = useState(false)

  const getExplorerUrl = (address: string) => {
    if (chainId === '8453') {
      return `https://basescan.org/address/${address}`
    }
    return `https://etherscan.io/address/${address}` // Default fallback
  }

  const handleCopy = () => {
    if (onCopy) {
      onCopy(address)
    } else {
      navigator.clipboard.writeText(address)
    }
  }

  return (
    <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
      <div className="flex items-center gap-3 mb-4">
        <div className={`w-10 h-10 ${color} rounded-lg flex items-center justify-center`}>
          <span className="text-white font-bold text-lg">{icon}</span>
        </div>
        <div className="flex-1">
          <h3 className="text-lg font-semibold text-white">{title}</h3>
          <p className="text-sm text-gray-400">{description}</p>
        </div>
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className="text-gray-400 hover:text-white transition-colors"
        >
          {isExpanded ? '▼' : '▶'}
        </button>
      </div>

      <div className="space-y-3">
        <div>
          <span className="text-gray-400 text-sm">Address:</span>
          <div className="font-mono text-sm bg-charcoal-700 p-2 rounded mt-1 break-all">
            {address}
          </div>
        </div>

        <div className="flex gap-2">
          <a
            href={getExplorerUrl(address)}
            target="_blank"
            rel="noopener noreferrer"
            className={`px-3 py-1 ${color} hover:opacity-80 text-white text-sm rounded transition-colors`}
          >
            View on Explorer
          </a>
          <button
            onClick={handleCopy}
            className={`px-3 py-1 text-sm rounded transition-colors ${
              copiedAddress === address
                ? 'bg-green-600 text-white'
                : 'bg-gray-600 hover:bg-gray-700 text-white'
            }`}
          >
            {copiedAddress === address ? 'Copied!' : 'Copy Address'}
          </button>
        </div>

        {isExpanded && (
          <div className="pt-4 border-t border-white/10">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-gray-400">Chain:</span>
                <div className="text-white font-medium">
                  {chainId === '8453' ? 'Base' : `Chain ${chainId}`}
                </div>
              </div>
              <div>
                <span className="text-gray-400">Status:</span>
                <div className="text-green-400 font-medium">✓ Deployed</div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
