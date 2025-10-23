'use client'

import type { FleetCommanderInfo } from '../types'

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
      <div className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-gray-400">
        Loading fleets...
      </div>
    )
  }

  return (
    <select
      value={selectedFleet}
      onChange={(e) => onFleetChange(e.target.value)}
      className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
    >
      <option value="">Select a fleet...</option>
      {fleets.map((fleet) => (
        <option key={fleet.address} value={fleet.address}>
          {fleet.name} ({fleet.symbol}) - {fleet.address.slice(0, 6)}...{fleet.address.slice(-4)}
        </option>
      ))}
    </select>
  )
}
