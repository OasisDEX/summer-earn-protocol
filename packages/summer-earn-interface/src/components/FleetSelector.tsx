'use client'

import type { FleetCommanderInfo } from '../types'
import { formatAddress } from '../utils/address'
import { selectBase } from './ui'

interface FleetSelectorProps {
  fleets: FleetCommanderInfo[]
  selectedFleet: string
  onFleetChange: (fleetAddress: string) => void
  loading?: boolean
}

export function FleetSelector({
  fleets,
  selectedFleet,
  onFleetChange,
  loading,
}: FleetSelectorProps) {
  if (loading) {
    return (
      <div className="w-full p-3 bg-surface-container border border-white/10 rounded-lg text-on-surface-variant">
        Loading fleets…
      </div>
    )
  }

  return (
    <select
      value={selectedFleet}
      onChange={(e) => onFleetChange(e.target.value)}
      className={`${selectBase} w-full`}
    >
      <option value="">Select a fleet…</option>
      {fleets.map((fleet) => (
        <option key={fleet.address} value={fleet.address}>
          {fleet.name} ({fleet.symbol}) - {formatAddress(fleet.address)}
        </option>
      ))}
    </select>
  )
}
