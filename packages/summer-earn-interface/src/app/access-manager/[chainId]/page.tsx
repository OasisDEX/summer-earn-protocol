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
      <div className="min-h-screen bg-gradient-to-b from-black via-charcoal-900 to-black p-6 md:p-10">
        <div className="max-w-7xl mx-auto">
          <div className="text-center text-red-400 bg-red-900/20 p-6 rounded-3xl border border-red-500/50 backdrop-blur-md">
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
    <main className="min-h-screen bg-gradient-to-b from-black via-charcoal-900 to-black p-6 md:p-10 text-gray-100 font-sans">
      <div className="max-w-7xl mx-auto space-y-8">
        <div className="space-y-6">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <button
                onClick={() => router.back()}
                className="px-5 py-2 bg-charcoal-800 hover:bg-gray-700 text-white rounded-xl border border-white/20 shadow-md transition-all duration-200 ease-in-out"
              >
                ← Back
              </button>
              <div className="flex items-center gap-3">
                <h1 className="text-3xl md:text-4xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-600">
                  Protocol Access Manager
                </h1>
                <span className="px-3 py-1 rounded-full border border-blue-500/30 bg-blue-900/20 text-xs uppercase tracking-wide text-blue-300 font-semibold h-fit">
                  {environment}
                </span>
              </div>
            </div>
          </div>
          <p className="text-gray-400 text-lg">
            Manage roles and permissions for the Summer Earn Protocol
          </p>

          <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
            <div className="flex flex-col gap-4 mb-6">
              <ChainSelector selectedChain={chainId} onChange={() => {}} readOnly />
            </div>

            <div className="bg-charcoal-800/50 p-4 rounded-xl border border-white/5">
              <p className="text-sm text-gray-300">
                <strong>Contract Address:</strong>{' '}
                <span className="font-mono text-blue-300">{protocolAccessManagerAddress}</span>
              </p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Role Selection */}
          <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
            <h2 className="text-xl font-bold text-white mb-6">Select Role</h2>

            <div className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">Role Type</label>
                <select
                  value={selectedRole}
                  onChange={(e) =>
                    setSelectedRole(e.target.value as GlobalRole | FleetRole | ArkRole)
                  }
                  className="w-full px-4 py-3 bg-charcoal-800/50 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all"
                >
                  <optgroup label="Global Roles" className="bg-charcoal-900 text-white">
                    <option value="GOVERNOR_ROLE">Governor</option>
                    <option value="SUPER_KEEPER_ROLE">Super Keeper</option>
                    <option value="GUARDIAN_ROLE">Guardian</option>
                    <option value="DECAY_CONTROLLER_ROLE">Decay Controller</option>
                    <option value="ADMIRALS_QUARTERS_ROLE">Admirals Quarters</option>
                    <option value="FOUNDATION_ROLE">Foundation</option>
                  </optgroup>
                  <optgroup label="Fleet Roles" className="bg-charcoal-900 text-white">
                    <option value="CURATOR_ROLE">Curator (Fleet-specific)</option>
                    <option value="KEEPER_ROLE">Keeper (Fleet-specific)</option>
                  </optgroup>
                  <optgroup label="Ark Roles" className="bg-charcoal-900 text-white">
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
                      className="w-full px-4 py-3 bg-charcoal-800/50 border border-white/10 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all"
                    />
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Role Management */}
          <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
            <RoleManager
              contractAddress={protocolAccessManagerAddress}
              selectedRole={selectedRole}
              targetContract={requiresTargetContract ? selectedFleet : undefined}
            />
          </div>
        </div>

        {/* Role Information */}
        <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
          <h2 className="text-xl font-bold text-white mb-4">Role Information</h2>
          <div className="text-gray-300 space-y-2 leading-relaxed">
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
