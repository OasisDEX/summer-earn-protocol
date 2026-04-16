import { useState } from 'react'
import { Action, SimulateApiResponse, SimulationResult } from '@/types/tenderly'

export function useSimulation() {
  const [results, setResults] = useState<Record<string, SimulationResult>>({})
  const [isSimulating, setIsSimulating] = useState(false)

  const triggerSimulation = async (actions: Action[]) => {
    setIsSimulating(true)
    const initialSimStatus: Record<string, SimulationResult> = {}

    // 1. Identify all target chains
    const targetChainIds = Array.from(new Set(actions.map((a) => a.chainId)))
    targetChainIds.forEach((cid) => {
      initialSimStatus[cid] = { chainId: cid, status: 'loading' }
    })
    setResults(initialSimStatus)

    try {
      const res = await fetch('/api/simulate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ actions }),
      })

      const data = (await res.json()) as SimulateApiResponse

      const updatedResults: Record<string, SimulationResult> = { ...initialSimStatus }

      Object.entries(data.results || {}).forEach(([cid, result]) => {
        if (result.error) {
          updatedResults[cid] = {
            chainId: cid,
            status: 'error',
            error: result.error,
            balance: result.balance,
          }
        } else {
          const simulations = result.simulation_results || []
          const failed = simulations.find((s) => !s.transaction.status)

          updatedResults[cid] = {
            chainId: cid,
            status: failed ? 'fail' : 'success',
            gasUsed: simulations.reduce((sum: number, s) => sum + (s.transaction.gas_used || 0), 0),
            simulationId: simulations[0]?.simulation.id,
            shareUrl: result.shareUrl,
            error: failed ? failed.transaction.error_message : undefined,
            balance: result.balance,
          }
        }
      })

      setResults(updatedResults)
    } catch (err) {
      console.error('Simulation call failed:', err)
    } finally {
      setIsSimulating(false)
    }
  }

  return {
    results,
    isSimulating,
    triggerSimulation,
    setResults
  }
}
