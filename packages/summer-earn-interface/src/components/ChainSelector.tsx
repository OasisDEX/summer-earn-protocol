'use client'

import { CHAIN_NAMES } from '../config/chains'
import { ChainId } from '../types'

interface ChainSelectorProps {
  selectedChain: ChainId
  onChange: (chain: ChainId) => void
}

export function ChainSelector({ selectedChain, onChange }: ChainSelectorProps) {
  return (
    <div className="flex flex-col space-y-2">
      <label htmlFor="chain-select" className="text-sm font-medium">
        Select Chain
      </label>
      <select
        id="chain-select"
        value={selectedChain}
        onChange={(e) => onChange(e.target.value as ChainId)}
        className="px-3 py-2 rounded-md border border-gray-300 focus:ring-blue-500 focus:border-blue-500 bg-gray-400"
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
