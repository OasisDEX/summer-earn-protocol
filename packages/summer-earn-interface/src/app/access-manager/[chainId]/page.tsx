'use client'

import { useState } from 'react'
import { useParams, useRouter } from 'next/navigation'

import { ChainSelector } from '../../../components/ChainSelector'
import { FleetSelector } from '../../../components/FleetSelector'
import { RoleManager } from '../../../components/RoleManager'
import { PROTOCOL_ACCESS_MANAGER_ADDRESSES } from '../../../config/environments'
import { useActiveFleets } from '../../../hooks/useActiveFleets'
import { useEnvironment } from '../../../hooks/useEnvironment'
import { useSyncWalletChain } from '../../../hooks/useSyncWalletChain'
import type { ArkRole, ChainId, FleetRole, GlobalRole } from '../../../types'

export default function AccessManagerPage() {
  const params = useParams()
  const router = useRouter()
  const chainId = params.chainId as ChainId
  const { environment } = useEnvironment()
  useSyncWalletChain(chainId)
  const [selectedRole, setSelectedRole] = useState<GlobalRole | FleetRole | ArkRole>(
    'GOVERNOR_ROLE',
  )
  const [selectedFleet, setSelectedFleet] = useState<string>('')

  const { fleets, loading: fleetsLoading } = useActiveFleets({
    chainId,
    environment,
  })

  const protocolAccessManagerAddress =
    PROTOCOL_ACCESS_MANAGER_ADDRESSES[environment][Number(chainId)]

  if (!protocolAccessManagerAddress) {
    return (
      <div className="min-h-screen bg-gray-100 p-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center text-red-600">
            Protocol Access Manager not configured for chain {chainId} in {environment} environment
          </div>
        </div>
      </div>
    )
  }

  const isFleetRole = (role: string): boolean => {
    return ['CURATOR_ROLE', 'KEEPER_ROLE'].includes(role)
  }

  const isArkRole = (role: string): boolean => {
    return ['COMMANDER_ROLE'].includes(role)
  }

  const requiresTargetContract = isFleetRole(selectedRole) || isArkRole(selectedRole)

  return (
    <main className="min-h-screen bg-black p-8">
      <div className="max-w-7xl mx-auto">
        <div className="mb-8">
          <div className="flex items-center gap-4 mb-4">
            <button
              onClick={() => router.back()}
              className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-semibold transition-colors"
            >
              ← Back
            </button>
            <h1 className="text-3xl font-bold text-white">Protocol Access Manager</h1>
          </div>
          <p className="text-gray-300 mb-6">
            Manage roles and permissions for the Summer Earn Protocol
          </p>

          <div className="flex flex-col gap-4 mb-6">
            <ChainSelector selectedChain={chainId} onChange={() => {}} readOnly />
          </div>

          <div className="bg-gray-800 p-4 rounded-lg mb-6">
            <p className="text-sm text-gray-300">
              <strong>Contract Address:</strong>{' '}
              <span className="font-mono text-blue-300">{protocolAccessManagerAddress}</span>
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Role Selection */}
          <div className="bg-gray-900 p-6 rounded-lg">
            <h2 className="text-xl font-semibold text-white mb-4">Select Role</h2>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">Role Type</label>
                <select
                  value={selectedRole}
                  onChange={(e) =>
                    setSelectedRole(e.target.value as GlobalRole | FleetRole | ArkRole)
                  }
                  className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <optgroup label="Global Roles">
                    <option value="GOVERNOR_ROLE">Governor</option>
                    <option value="SUPER_KEEPER_ROLE">Super Keeper</option>
                    <option value="GUARDIAN_ROLE">Guardian</option>
                    <option value="DECAY_CONTROLLER_ROLE">Decay Controller</option>
                    <option value="ADMIRALS_QUARTERS_ROLE">Admirals Quarters</option>
                    <option value="FOUNDATION_ROLE">Foundation</option>
                  </optgroup>
                  <optgroup label="Fleet Roles">
                    <option value="CURATOR_ROLE">Curator (Fleet-specific)</option>
                    <option value="KEEPER_ROLE">Keeper (Fleet-specific)</option>
                  </optgroup>
                  <optgroup label="Ark Roles">
                    <option value="COMMANDER_ROLE">Commander (Ark-specific)</option>
                  </optgroup>
                </select>
              </div>

              {requiresTargetContract && (
                <div>
                  <label className="block text-sm font-medium text-gray-300 mb-2">
                    {isFleetRole(selectedRole) ? 'Select Fleet' : 'Select Ark'}
                  </label>
                  {isFleetRole(selectedRole) ? (
                    <FleetSelector
                      fleets={fleets}
                      selectedFleet={selectedFleet}
                      onFleetChange={setSelectedFleet}
                      loading={fleetsLoading}
                    />
                  ) : (
                    <input
                      type="text"
                      placeholder="Enter Ark address"
                      value={selectedFleet}
                      onChange={(e) => setSelectedFleet(e.target.value)}
                      className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Role Management */}
          <div className="bg-gray-900 p-6 rounded-lg">
            <RoleManager
              contractAddress={protocolAccessManagerAddress}
              selectedRole={selectedRole}
              targetContract={requiresTargetContract ? selectedFleet : undefined}
            />
          </div>
        </div>

        {/* Role Information */}
        <div className="mt-8 bg-gray-900 p-6 rounded-lg">
          <h2 className="text-xl font-semibold text-white mb-4">Role Information</h2>
          <div className="text-gray-300 space-y-2">
            {selectedRole === 'GOVERNOR_ROLE' && (
              <p>
                Governors have the highest privilege level with admin capabilities across the entire
                protocol.
              </p>
            )}
            {selectedRole === 'SUPER_KEEPER_ROLE' && (
              <p>Super Keepers can globally perform fleet maintenance roles across all fleets.</p>
            )}
            {selectedRole === 'GUARDIAN_ROLE' && (
              <p>
                Guardians have emergency powers to pause operations and cancel proposals for
                protocol security.
              </p>
            )}
            {selectedRole === 'DECAY_CONTROLLER_ROLE' && (
              <p>
                Decay Controllers manage the decay of user voting power in the governance system.
              </p>
            )}
            {selectedRole === 'ADMIRALS_QUARTERS_ROLE' && (
              <p>
                Admirals Quarters role allows unstaking and withdrawing assets from fleets on behalf
                of users.
              </p>
            )}
            {selectedRole === 'FOUNDATION_ROLE' && (
              <p>Foundation role manages vesting wallets and related operations.</p>
            )}
            {selectedRole === 'CURATOR_ROLE' && (
              <p>
                Curators manage specific fleet operations and configurations for the selected fleet.
              </p>
            )}
            {selectedRole === 'KEEPER_ROLE' && (
              <p>Keepers perform routine maintenance operations for the selected fleet.</p>
            )}
            {selectedRole === 'COMMANDER_ROLE' && (
              <p>
                Commanders manage specific ark operations and configurations for the selected ark.
              </p>
            )}
          </div>
        </div>
      </div>
    </main>
  )
}
