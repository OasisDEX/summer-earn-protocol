'use client'

import React, { useMemo, useState } from 'react'
import { Play } from 'lucide-react'

import { SimulationModal } from '@/components/SimulationCenter/SimulationModal'
import { CHAINS, HUB_CHAIN_ID } from '@/config/chains'
import { useSimulation } from '@/hooks/useSimulation'
import { decodeCrossChainCalldata } from '@/services/validation'
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

    const simActions: Action[] = []

    fullProposal.baseProposal.targets.forEach((target, i) => {
      const calldata = fullProposal.baseProposal.calldatas[i]
      const value = fullProposal.baseProposal.values[i]?.toString() || '0'

      simActions.push({
        chainId: HUB_CHAIN_ID,
        target,
        method: 'unknown',
        calldata,
        salt: fullProposal.baseProposal.salt,
        value,
      })

      const decodedCrossChain = decodeCrossChainCalldata(calldata)
      if (decodedCrossChain) {
        const satelliteChain = CHAINS.find((c) => c.key === decodedCrossChain.dstEid)
        if (satelliteChain) {
          decodedCrossChain.dstTargets.forEach((dstTarget, j) => {
            simActions.push({
              chainId: satelliteChain.id,
              target: dstTarget,
              method: 'unknown',
              calldata: decodedCrossChain.dstCalldatas[j],
              salt: fullProposal.baseProposal.salt,
              value: decodedCrossChain.dstValues[j]?.toString() || '0',
            })
          })
        }
      }
    })

    fullProposal.crossChainProposals.forEach((ccp) => {
      ccp.targets.forEach((target, i) => {
        const calldata = ccp.calldatas[i]
        const alreadyExists = simActions.some(
          (a) =>
            a.chainId === ccp.chainId &&
            a.target.toLowerCase() === target.toLowerCase() &&
            a.calldata.toLowerCase() === calldata.toLowerCase(),
        )
        if (!alreadyExists) {
          simActions.push({
            chainId: ccp.chainId,
            target,
            method: 'unknown',
            calldata,
            salt: ccp.salt,
            value: ccp.values[i]?.toString() || '0',
          })
        }
      })
    })

    return simActions
  }, [fullProposal, isTerminalState])

  const targetChainIds = useMemo(
    () => Array.from(new Set(actions.map((a) => a.chainId))),
    [actions],
  )

  const handleSimulate = () => {
    if (!isModalOpen) setIsModalOpen(true)
    triggerSimulation(actions, fullProposal.baseProposal.id)
  }

  if (isTerminalState) return null

  return (
    <>
      <button
        onClick={() => setIsModalOpen(true)}
        className="h-[34px] px-3.5 rounded-lg border border-line2 bg-surface3 text-brand-pink font-semibold text-xs cursor-pointer hover:bg-surface2 transition-colors inline-flex items-center gap-2"
      >
        <Play size={13} fill="currentColor" />
        Run simulation
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
