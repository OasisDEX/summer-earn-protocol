'use client'

import { CHAIN_NAMES } from '@/config/chains'
import type { ChainId } from '@/types'

const CHAIN_ORDER: ChainId[] = ['1', '42161', '8453', '146']

const CHAIN_INITIALS: Record<ChainId, string> = {
  '1': 'E',
  '42161': 'A',
  '8453': 'B',
  '146': 'S',
  '999': 'T',
}

interface ChainPillsProps {
  selectedChain: ChainId
  onChange: (chain: ChainId) => void
  chains?: ChainId[]
}

export function ChainPills({ selectedChain, onChange, chains = CHAIN_ORDER }: ChainPillsProps) {
  return (
    <div className="flex items-center bg-white/5 border border-white/10 p-1.5 rounded-xl">
      {chains.map((chainId) => {
        const isActive = selectedChain === chainId
        const name = CHAIN_NAMES[chainId]
        const initial = CHAIN_INITIALS[chainId] ?? name.charAt(0)

        return (
          <button
            key={chainId}
            type="button"
            onClick={() => onChange(chainId)}
            className={`flex items-center space-x-2 px-5 py-2.5 rounded-lg font-medium transition-all ${
              isActive
                ? 'bg-white/10 text-white shadow-xl'
                : 'text-slate-400 hover:text-white hover:bg-white/5'
            }`}
          >
            <div
              className={`w-5 h-5 rounded-full flex items-center justify-center text-xs font-bold ${
                isActive ? 'bg-primary/30 text-primary' : 'bg-white/10 text-slate-500'
              }`}
            >
              {initial}
            </div>
            <span>{name}</span>
          </button>
        )
      })}
    </div>
  )
}
