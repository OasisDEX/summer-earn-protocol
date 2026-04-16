'use client'

import React, { useMemo, useState } from 'react'
import { Play } from 'lucide-react'

import { SimulationModal } from '@/components/SimulationCenter/SimulationModal'
import { useSimulation } from '@/hooks/useSimulation'
import { FinalStatus, ProposalWithCrossChain } from '@/types/governance'
import { Action } from '@/types/tenderly'

interface SimulateProposalButtonProps {
  fullProposal: ProposalWithCrossChain
  status: FinalStatus
}

export function SimulateProposalButton({ fullProposal, status }: SimulateProposalButtonProps) {
  const [isModalOpen, setIsModalOpen] = useState(false)
  const { results, isSimulating, triggerSimulation } = useSimulation()

  const isTerminalState = ['Executed', 'Canceled', 'Defeated', 'Executed on Hub'].includes(status)

  const actions = useMemo(() => {
    if (isTerminalState) return []

    // 1. Hub chain actions (baseProposal)
    // We assume the hub chain ID is 8453 (Base) but should ideally get it from proposal.chain
    // However, baseProposal.targets and calldatas are definitely for the Hub.
    const hubChainId = '8453'
    const simActions: Action[] = []

    fullProposal.baseProposal.targets.forEach((target, i) => {
      const calldata = fullProposal.baseProposal.calldatas[i]

      // We skip things that look like cross-chain initiators IF they are already represented
      // in crossChainProposals. But simulation API wants the LOW LEVEL calls.
      // If we simulate the initiator, it might not actually 'do' the satellite work in Tenderly
      // without extra cross-chain simulation support.
      // For now, we simulate what's EXACTLY in the proposal.

      simActions.push({
        chainId: hubChainId,
        target,
        method: 'unknown',
        calldata,
        salt: fullProposal.baseProposal.salt,
        value: fullProposal.baseProposal.values[i]?.toString() || '0',
      })
    })

    // 2. Satellite chain actions
    fullProposal.crossChainProposals.forEach((ccp) => {
      ccp.targets.forEach((target, i) => {
        simActions.push({
          chainId: ccp.chainId,
          target,
          method: 'unknown',
          calldata: ccp.calldatas[i],
          salt: ccp.salt,
          value: ccp.values[i]?.toString() || '0',
        })
      })
    })

    return simActions
  }, [fullProposal])

  const targetChainIds = useMemo(
    () => Array.from(new Set(actions.map((a) => a.chainId))),
    [actions],
  )

  const handleSimulate = () => {
    if (!isModalOpen) setIsModalOpen(true)
    triggerSimulation(actions)
  }

  if (isTerminalState) return null

  return (
    <>
      <button
        onClick={() => setIsModalOpen(true)}
        className="flex items-center gap-2 px-4 py-2 bg-primary/10 hover:bg-primary/20 text-primary border border-primary/20 rounded-xl text-xs font-bold transition-all active:scale-95"
      >
        <Play size={14} fill="currentColor" />
        Simulate Transactions
      </button>

      <SimulationModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        results={results}
        isSimulating={isSimulating}
        onSimulate={handleSimulate}
        targetChainIds={targetChainIds}
      />
    </>
  )
}
