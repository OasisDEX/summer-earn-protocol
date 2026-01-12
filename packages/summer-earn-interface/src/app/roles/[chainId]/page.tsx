'use client'

import { useMemo, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'

import { ChainSelector } from '../../../components/ChainSelector'
import { CHAIN_BLOCK_EXPLORERS } from '../../../config/chains'
import { useRoles } from '../../../hooks/useRoles'
import { useSyncWalletChain } from '../../../hooks/useSyncWalletChain'
import type { ChainId } from '../../../types'
import { getAllAddressLabels } from '../../../utils/configAddresses'

type SortColumn = 'role' | 'owner' | null
type SortDirection = 'asc' | 'desc'

export default function AccessManagementPage() {
  const params = useParams()
  const router = useRouter()
  const chainId = params.chainId as ChainId
  const [activeOnly, setActiveOnly] = useState(true)
  const [roleFilter, setRoleFilter] = useState('')
  const [ownerFilter, setOwnerFilter] = useState('')
  const [sortColumn, setSortColumn] = useState<SortColumn>(null)
  const [sortDirection, setSortDirection] = useState<SortDirection>('asc')
  useSyncWalletChain(chainId)

  const { data, isLoading, error } = useRoles({ chainId, activeOnly })
  const addressLabels = getAllAddressLabels(chainId)
  const blockExplorer = CHAIN_BLOCK_EXPLORERS[chainId]

  const allRoles = data?.roles || []

  // Filter and sort roles
  const roles = useMemo(() => {
    let filtered = [...allRoles]

    // Apply filters
    if (roleFilter.trim()) {
      const filterLower = roleFilter.toLowerCase()
      filtered = filtered.filter((role) => role.name.toLowerCase().includes(filterLower))
    }

    if (ownerFilter.trim()) {
      const filterLower = ownerFilter.toLowerCase()
      filtered = filtered.filter(
        (role) =>
          role.owner.toLowerCase().includes(filterLower) ||
          addressLabels[role.owner.toLowerCase()]?.toLowerCase().includes(filterLower),
      )
    }

    // Apply sorting
    if (sortColumn) {
      filtered.sort((a, b) => {
        let aValue: string
        let bValue: string

        if (sortColumn === 'role') {
          aValue = a.name.toLowerCase()
          bValue = b.name.toLowerCase()
        } else if (sortColumn === 'owner') {
          // Use label if available, otherwise use address
          aValue = addressLabels[a.owner.toLowerCase()]?.toLowerCase() || a.owner.toLowerCase()
          bValue = addressLabels[b.owner.toLowerCase()]?.toLowerCase() || b.owner.toLowerCase()
        } else {
          return 0
        }

        const comparison = aValue.localeCompare(bValue)
        return sortDirection === 'asc' ? comparison : -comparison
      })
    }

    return filtered
  }, [allRoles, roleFilter, ownerFilter, sortColumn, sortDirection, addressLabels])

  const handleSort = (column: SortColumn) => {
    if (sortColumn === column) {
      // Toggle direction if clicking the same column
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      // Set new column and default to ascending
      setSortColumn(column)
      setSortDirection('asc')
    }
  }

  const formatTimestamp = (timestamp: string): string => {
    const date = new Date(parseInt(timestamp) * 1000)
    return date.toLocaleString()
  }

  const getAddressLabel = (address: string): string | null => {
    return addressLabels[address.toLowerCase()] || null
  }

  const truncateAddress = (address: string): string => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`
  }

  const getRoleBadgeColor = (roleName: string): string => {
    if (roleName.includes('GOVERNOR')) return 'bg-purple-900 text-purple-200'
    if (roleName.includes('GUARDIAN')) return 'bg-red-900 text-red-200'
    if (roleName.includes('KEEPER')) return 'bg-blue-900 text-blue-200'
    if (roleName.includes('CURATOR')) return 'bg-green-900 text-green-200'
    if (roleName.includes('COMMANDER')) return 'bg-yellow-900 text-yellow-200'
    if (roleName.includes('PROPOSER')) return 'bg-indigo-900 text-indigo-200'
    if (roleName.includes('EXECUTOR')) return 'bg-teal-900 text-teal-200'
    if (roleName.includes('CANCELLER')) return 'bg-orange-900 text-orange-200'
    return 'bg-gray-800 text-gray-200'
  }

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
            <h1 className="text-3xl font-bold text-white">Access Management</h1>
          </div>
          <p className="text-gray-300 mb-6">
            View all roles granted across ProtocolAccessManager and TimelockController contracts
          </p>

          <div className="flex flex-col gap-4 mb-6">
            <ChainSelector selectedChain={chainId} onChange={() => {}} readOnly />
          </div>

          <div className="space-y-4 mb-6">
            <div className="flex items-center gap-4">
              <label className="flex items-center gap-2 text-gray-300">
                <input
                  type="checkbox"
                  checked={activeOnly}
                  onChange={(e) => setActiveOnly(e.target.checked)}
                  className="w-4 h-4 rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500"
                />
                <span>Show active roles only</span>
              </label>
              <div className="text-sm text-gray-400">
                Showing {roles.length} of {allRoles.length} roles
                {activeOnly && ` (${allRoles.filter((r) => r.active).length} active total)`}
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Filter by Role Name
                </label>
                <input
                  type="text"
                  placeholder="Search roles..."
                  value={roleFilter}
                  onChange={(e) => setRoleFilter(e.target.value)}
                  className="w-full p-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Filter by Owner Address
                </label>
                <input
                  type="text"
                  placeholder="Search owner address..."
                  value={ownerFilter}
                  onChange={(e) => setOwnerFilter(e.target.value)}
                  className="w-full p-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent font-mono text-sm"
                />
              </div>
            </div>
          </div>
        </div>

        {isLoading && (
          <div className="text-center py-12">
            <div className="text-gray-400">Loading roles...</div>
          </div>
        )}

        {error && (
          <div className="bg-red-900 border border-red-600 rounded-lg p-4 mb-6">
            <p className="text-red-200">
              <strong>Error:</strong> Failed to load roles.{' '}
              {error instanceof Error ? error.message : 'Unknown error'}
            </p>
          </div>
        )}

        {!isLoading && !error && (
          <div className="bg-gray-900 rounded-lg overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-800 border-b border-gray-700">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                      <button
                        onClick={() => handleSort('role')}
                        className="flex items-center gap-2 hover:text-white transition-colors"
                      >
                        Role
                        {sortColumn === 'role' && (
                          <span className="text-blue-400">
                            {sortDirection === 'asc' ? '↑' : '↓'}
                          </span>
                        )}
                      </button>
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                      <button
                        onClick={() => handleSort('owner')}
                        className="flex items-center gap-2 hover:text-white transition-colors"
                      >
                        Owner
                        {sortColumn === 'owner' && (
                          <span className="text-blue-400">
                            {sortDirection === 'asc' ? '↑' : '↓'}
                          </span>
                        )}
                      </button>
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                      Target Contract
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                      Access Controller
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                      Status
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                      Created
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider">
                      Last Event
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-700">
                  {roles.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="px-6 py-8 text-center text-gray-400">
                        No roles found
                      </td>
                    </tr>
                  ) : (
                    roles.map((role) => {
                      const ownerLabel = getAddressLabel(role.owner)
                      const targetLabel = getAddressLabel(role.targetContract)
                      const controllerLabel = getAddressLabel(role.accessController)
                      const lastEvent = role.events?.[0]

                      return (
                        <tr key={role.id} className="hover:bg-gray-800 transition-colors">
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span
                              className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getRoleBadgeColor(role.name)}`}
                            >
                              {role.name}
                            </span>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center gap-2">
                              <a
                                href={`${blockExplorer}/address/${role.owner}`}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="font-mono text-blue-400 hover:text-blue-300"
                              >
                                {truncateAddress(role.owner)}
                              </a>
                              {ownerLabel && (
                                <span className="px-2 py-0.5 bg-gray-700 text-gray-300 text-xs rounded">
                                  {ownerLabel}
                                </span>
                              )}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            {role.targetContract !==
                            '0x0000000000000000000000000000000000000000' ? (
                              <div className="flex items-center gap-2">
                                <a
                                  href={`${blockExplorer}/address/${role.targetContract}`}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="font-mono text-blue-400 hover:text-blue-300"
                                >
                                  {truncateAddress(role.targetContract)}
                                </a>
                                {targetLabel && (
                                  <span className="px-2 py-0.5 bg-gray-700 text-gray-300 text-xs rounded">
                                    {targetLabel}
                                  </span>
                                )}
                              </div>
                            ) : (
                              <span className="text-gray-500">—</span>
                            )}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center gap-2">
                              <a
                                href={`${blockExplorer}/address/${role.accessController}`}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="font-mono text-blue-400 hover:text-blue-300"
                              >
                                {truncateAddress(role.accessController)}
                              </a>
                              {controllerLabel && (
                                <span className="px-2 py-0.5 bg-gray-700 text-gray-300 text-xs rounded">
                                  {controllerLabel}
                                </span>
                              )}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span
                              className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                role.active
                                  ? 'bg-green-900 text-green-200'
                                  : 'bg-red-900 text-red-200'
                              }`}
                            >
                              {role.active ? 'Active' : 'Inactive'}
                            </span>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                            {formatTimestamp(role.createdTimestamp)}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            {lastEvent ? (
                              <div className="text-sm">
                                <div className="text-gray-300">
                                  {lastEvent.action === 'GRANT_ROLE' ? 'Granted' : 'Revoked'}
                                </div>
                                <a
                                  href={`${blockExplorer}/tx/${lastEvent.hash}`}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="text-blue-400 hover:text-blue-300 font-mono text-xs"
                                >
                                  {truncateAddress(lastEvent.hash)}
                                </a>
                                <div className="text-gray-500 text-xs">
                                  {formatTimestamp(lastEvent.timestamp)}
                                </div>
                              </div>
                            ) : (
                              <span className="text-gray-500">—</span>
                            )}
                          </td>
                        </tr>
                      )
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </main>
  )
}
