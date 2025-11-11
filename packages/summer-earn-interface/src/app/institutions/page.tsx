'use client'

import { useMemo, useState } from 'react'
import Link from 'next/link'
import { useAccount } from 'wagmi'

import { AdmiralsWhitelistToggle } from '@/components/AdmiralsWhitelistToggle'
import { ChainSelector } from '@/components/ChainSelector'
import { InstitutionRolesPanel } from '@/components/InstitutionRolesPanel'
import { InstitutionSelector } from '@/components/InstitutionSelector'
import { WhitelistManager } from '@/components/WhitelistManager'
import { useInstitutionRoles, useInstitutions, useInstitutionVaults } from '@/hooks/useInstitutions'
import { useLocalStorage } from '@/hooks/useLocalStorage'
import type { ChainId } from '@/types'
import type { RoleEntity, VaultEntity } from '@/types/subgraph'

export default function InstitutionsPage() {
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>('selectedChain', '1')
  const [selectedChain, setSelectedChain] = useState<ChainId>(storedChain)
  const [institutionId, setInstitutionId] = useState<string>('')
  const { address: connected, isConnected } = useAccount()
  const { data: institutions = [] } = useInstitutions(selectedChain)

  const { data: roles = [], isLoading: rolesLoading } = useInstitutionRoles(
    selectedChain,
    institutionId,
  )
  const { data: vaults = [], isLoading: vaultsLoading } = useInstitutionVaults(
    selectedChain,
    institutionId,
  )

  const selectedInstitution = useMemo(
    () => institutions.find((i) => i.id === institutionId),
    [institutions, institutionId],
  )
  const isAdmin = useMemo(() => {
    if (!connected) return false
    // Admins are those with GOVERNOR_ROLE entries; subgraph role names assumed to match
    return roles.some(
      (r) => r.name === 'GOVERNOR_ROLE' && r.owner.toLowerCase() === connected.toLowerCase(),
    )
  }, [roles, connected])

  type ExtendedVaultEntity = VaultEntity & { address?: string | null }

  const groupedRoles = useMemo(() => {
    const groups: Record<string, { name: string; items: RoleEntity[] }> = {}
    for (const r of roles) {
      if (!groups[r.name]) groups[r.name] = { name: r.name, items: [] }
      groups[r.name].items.push(r)
    }
    return groups
  }, [roles])

  return (
    <main className="min-h-screen bg-charcoal-900 p-8">
      <div className="max-w-7xl mx-auto space-y-8">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">Institutions</h1>
          <p className="text-gray-300">Manage institutional roles and vault whitelist access</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
          <ChainSelector
            selectedChain={selectedChain}
            onChange={(c) => {
              setSelectedChain(c)
              setStoredChain(c)
            }}
          />
          <InstitutionSelector
            chainId={selectedChain}
            value={institutionId}
            onChange={setInstitutionId}
          />
        </div>

        {institutionId && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div className="lg:col-span-2 space-y-6">
              <section className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10">
                <h2 className="text-xl font-semibold text-white mb-4">Vaults</h2>
                {vaultsLoading ? (
                  <p className="text-gray-400">Loading vaults...</p>
                ) : vaults.length === 0 ? (
                  <p className="text-gray-400">No vaults found for this institution.</p>
                ) : (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {vaults.map((vault) => {
                      const { address: maybeAddress, id, name } = vault as ExtendedVaultEntity
                      const address: string | undefined = maybeAddress ?? id
                      const isAddress =
                        typeof address === 'string' &&
                        address.startsWith('0x') &&
                        address.length === 42
                      return (
                        <div
                          key={id}
                          className="p-4 bg-gray-900 rounded-lg border border-white/10 space-y-3"
                        >
                          <div className="flex items-center justify-between">
                            <div>
                              <h3 className="text-white font-semibold">{name ?? 'Vault'}</h3>
                              <p className="text-sm text-blue-300 font-mono break-all">{address}</p>
                            </div>
                          </div>
                          {isAddress && (
                            <div className="flex items-center justify-between gap-3">
                              <Link
                                href={`/fleet/${selectedChain}/${address}`}
                                className="text-blue-400 hover:text-blue-300 text-sm font-medium transition-colors"
                              >
                                View Vault →
                              </Link>
                              {isAdmin && <div className="flex-1" />}
                            </div>
                          )}
                          {isAddress && isAdmin && (
                            <WhitelistManager fleetAddress={address as `0x${string}`} />
                          )}
                        </div>
                      )
                    })}
                  </div>
                )}
              </section>

              <section className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10">
                <h2 className="text-xl font-semibold text-white mb-4">Roles</h2>
                {rolesLoading ? (
                  <p className="text-gray-400">Loading roles...</p>
                ) : (
                  <div className="space-y-6">
                    {Object.values(groupedRoles).length === 0 && (
                      <p className="text-gray-400">No roles found in subgraph.</p>
                    )}
                    {Object.values(groupedRoles).map((group) => (
                      <div
                        key={group.name}
                        className="bg-gray-900 p-4 rounded-lg border border-white/10"
                      >
                        <h3 className="text-white font-semibold mb-3">{group.name}</h3>
                        <div className="space-y-2">
                          {group.items.map((r) => (
                            <div
                              key={r.id}
                              className="text-sm text-gray-300 grid grid-cols-1 md:grid-cols-3 gap-2"
                            >
                              <div>
                                <span className="text-gray-400">Owner:</span>{' '}
                                <span className="font-mono text-blue-300 break-all">{r.owner}</span>
                              </div>
                              <div>
                                <span className="text-gray-400">Target:</span>{' '}
                                <span className="font-mono text-blue-300 break-all">
                                  {r.targetContract}
                                </span>
                              </div>
                              <div>
                                <span className="text-gray-400">AccessController:</span>{' '}
                                <span className="font-mono text-blue-300 break-all">
                                  {r.accessController}
                                </span>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </section>
            </div>
            <aside className="space-y-6">
              <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10">
                <h2 className="text-xl font-semibold text-white mb-4">Notes</h2>
                <ul className="list-disc list-inside text-gray-300 text-sm space-y-2">
                  <li>
                    {isConnected
                      ? isAdmin
                        ? 'You are an institution admin.'
                        : 'You are not an institution admin.'
                      : 'Connect wallet to check admin status.'}
                  </li>
                  <li>Whitelist changes require institution governor role</li>
                  <li>Roles are read from the institutions subgraph</li>
                </ul>
              </div>
              {selectedInstitution && isAdmin && (
                <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 space-y-4">
                  <h2 className="text-xl font-semibold text-white">Institution Admin</h2>
                  {selectedInstitution.admiralsQuarters && (
                    <AdmiralsWhitelistToggle
                      admiralsQuarters={selectedInstitution.admiralsQuarters as `0x${string}`}
                    />
                  )}
                  {selectedInstitution.protocolAccessManager && (
                    <InstitutionRolesPanel
                      protocolAccessManager={
                        selectedInstitution.protocolAccessManager as `0x${string}`
                      }
                      fleets={
                        vaults
                          .map((vault) => {
                            const { address: maybeAddress, id, name } = vault as ExtendedVaultEntity
                            const address: string | undefined = maybeAddress ?? id
                            const isAddress =
                              typeof address === 'string' &&
                              address.startsWith('0x') &&
                              address.length === 42
                            if (!isAddress) return null
                            return {
                              address: address as `0x${string}`,
                              label: name ? `${name} (${address})` : address,
                            }
                          })
                          .filter(Boolean) as { address: `0x${string}`; label: string }[]
                      }
                    />
                  )}
                </div>
              )}
            </aside>
          </div>
        )}
      </div>
    </main>
  )
}
