'use client'

import React from 'react'

import { CHAINS } from '@/config/chains'
import { SimulationResult } from '@/types/tenderly'

import { SimCard } from './SimCard'

interface SimulationCenterProps {
  results: Record<string, SimulationResult>
  targetChainIds: string[]
}

export function SimulationCenter({ results, targetChainIds }: SimulationCenterProps) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {CHAINS.map((chain) => (
        <SimCard
          key={chain.id}
          chain={chain}
          isTargeted={targetChainIds.includes(chain.id)}
          result={results[chain.id]}
        />
      ))}
    </div>
  )
}
