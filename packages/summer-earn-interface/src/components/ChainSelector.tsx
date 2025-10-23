'use client'

import { CHAIN_NAMES } from '../config/chains'
import { ChainId } from '../types'

interface ChainSelectorProps {
  selectedChain: ChainId
  onChange: (chain: ChainId) => void
  readOnly?: boolean
}

export function ChainSelector({ selectedChain, onChange, readOnly = false }: ChainSelectorProps) {
  return (
    <div className="flex flex-col space-y-2">
      <label htmlFor="chain-select" className="text-sm font-medium text-white">
        Select Chain
      </label>
      <select
        id="chain-select"
        value={selectedChain}
        onChange={(e) => onChange(e.target.value as ChainId)}
        disabled={readOnly}
        className={`px-3 py-2 rounded-lg border border-gray-700 focus:ring-2 focus:ring-blue-500 focus:border-transparent text-white ${
          readOnly ? 'bg-gray-700 cursor-not-allowed' : 'bg-gray-800'
        }`}
      >
        {Object.entries(CHAIN_NAMES).map(([id, name]) => (
          <option key={id} value={id}>
            {name}
          </option>
        ))}
      </select>
    </div>
  )
}
