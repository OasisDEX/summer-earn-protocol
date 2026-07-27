'use client'

import { CHAIN_NAMES } from '../config/chains'
import { ChainId } from '../types'
import { selectBase } from './ui'

interface ChainSelectorProps {
  selectedChain: ChainId
  onChange: (chain: ChainId) => void
  readOnly?: boolean
}

export function ChainSelector({ selectedChain, onChange, readOnly = false }: ChainSelectorProps) {
  return (
    <div className="flex flex-col space-y-2">
      <label htmlFor="chain-select" className="text-sm font-medium text-on-surface">
        Select Chain
      </label>
      <select
        id="chain-select"
        value={selectedChain}
        onChange={(e) => onChange(e.target.value as ChainId)}
        disabled={readOnly}
        className={selectBase}
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
