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
      <label htmlFor="chain-select" className="text-sm font-bold text-white">
        Select Chain
      </label>
      <select
        id="chain-select"
        value={selectedChain}
        onChange={(e) => onChange(e.target.value as ChainId)}
        disabled={readOnly}
        className={`w-full px-4 py-3 rounded-xl border border-white/10 text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all ${
          readOnly
            ? 'bg-charcoal-800/50 cursor-not-allowed opacity-70'
            : 'bg-charcoal-800/50 hover:bg-charcoal-800/80'
        }`}
      >
        {Object.entries(CHAIN_NAMES).map(([id, name]) => (
          <option key={id} value={id} className="bg-charcoal-900 text-white">
            {name}
          </option>
        ))}
      </select>
    </div>
  )
}
