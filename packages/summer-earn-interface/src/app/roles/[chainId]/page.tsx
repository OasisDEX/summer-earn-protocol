'use client'

import { useMemo, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'

import { ChainSelector } from '../../../components/ChainSelector'
import {
  AddressDisplay,
  Badge,
  Button,
  checkboxBase,
  inputBase,
  labelBase,
  PageHeader,
  RetiredDataNotice,
  Table,
  TableContainer,
  TBody,
  Td,
  Th,
  THead,
  Tr,
} from '../../../components/ui'
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

  // Pure display mapping: role-name substring → shared Badge tone
  const getRoleBadgeTone = (
    roleName: string,
  ): 'neutral' | 'primary' | 'success' | 'warning' | 'danger' | 'info' => {
    if (roleName.includes('GOVERNOR')) return 'primary'
    if (roleName.includes('GUARDIAN')) return 'danger'
    if (roleName.includes('KEEPER')) return 'info'
    if (roleName.includes('CURATOR')) return 'success'
    if (roleName.includes('COMMANDER')) return 'warning'
    if (roleName.includes('PROPOSER')) return 'info'
    if (roleName.includes('EXECUTOR')) return 'success'
    if (roleName.includes('CANCELLER')) return 'warning'
    return 'neutral'
  }

  return (
    <main className="min-h-screen p-8">
      <div className="max-w-7xl mx-auto">
        <div className="mb-8">
          <div className="mb-3">
            <Button variant="secondary" size="sm" onClick={() => router.back()}>
              ← Back
            </Button>
          </div>
          <PageHeader
            title="Access Management"
            description="View all roles granted across ProtocolAccessManager and TimelockController contracts"
            actions={<ChainSelector selectedChain={chainId} onChange={() => {}} readOnly />}
          />

          <div className="space-y-4 mb-6">
            <div className="flex items-center gap-4">
              <label className="flex items-center gap-2 text-on-surface-variant">
                <input
                  type="checkbox"
                  checked={activeOnly}
                  onChange={(e) => setActiveOnly(e.target.checked)}
                  className={checkboxBase}
                />
                <span>Show active roles only</span>
              </label>
              <div className="text-sm text-on-surface-variant tabular-nums">
                Showing {roles.length} of {allRoles.length} roles
                {activeOnly && ` (${allRoles.filter((r) => r.active).length} active total)`}
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className={labelBase}>Filter by Role Name</label>
                <input
                  type="text"
                  placeholder="Search roles…"
                  value={roleFilter}
                  onChange={(e) => setRoleFilter(e.target.value)}
                  className={inputBase}
                />
              </div>
              <div>
                <label className={labelBase}>Filter by Owner Address</label>
                <input
                  type="text"
                  placeholder="Search owner address…"
                  value={ownerFilter}
                  onChange={(e) => setOwnerFilter(e.target.value)}
                  className={`${inputBase} font-mono text-sm`}
                />
              </div>
            </div>
          </div>
        </div>

        {isLoading && (
          <div className="text-center py-12">
            <div className="text-on-surface-variant">Loading roles…</div>
          </div>
        )}

        {error && <RetiredDataNotice what="The roles subgraph" />}

        {!isLoading && !error && (
          <TableContainer>
            <Table>
              <THead className="bg-white/[0.03]">
                <Tr>
                  <Th>
                    <button
                      onClick={() => handleSort('role')}
                      className="flex items-center gap-2 uppercase tracking-wider hover:text-on-surface transition-colors"
                    >
                      Role
                      {sortColumn === 'role' && (
                        <span className="text-primary">{sortDirection === 'asc' ? '↑' : '↓'}</span>
                      )}
                    </button>
                  </Th>
                  <Th>
                    <button
                      onClick={() => handleSort('owner')}
                      className="flex items-center gap-2 uppercase tracking-wider hover:text-on-surface transition-colors"
                    >
                      Owner
                      {sortColumn === 'owner' && (
                        <span className="text-primary">{sortDirection === 'asc' ? '↑' : '↓'}</span>
                      )}
                    </button>
                  </Th>
                  <Th>Target Contract</Th>
                  <Th>Access Controller</Th>
                  <Th>Status</Th>
                  <Th>Created</Th>
                  <Th>Last Event</Th>
                </Tr>
              </THead>
              <TBody>
                {roles.length === 0 ? (
                  <Tr>
                    <Td colSpan={7} align="center" className="py-8 text-on-surface-variant">
                      No roles found
                    </Td>
                  </Tr>
                ) : (
                  roles.map((role) => {
                    const ownerLabel = getAddressLabel(role.owner)
                    const targetLabel = getAddressLabel(role.targetContract)
                    const controllerLabel = getAddressLabel(role.accessController)
                    const lastEvent = role.events?.[0]

                    return (
                      <Tr key={role.id} hover>
                        <Td className="whitespace-nowrap">
                          <Badge tone={getRoleBadgeTone(role.name)} size="sm">
                            {role.name}
                          </Badge>
                        </Td>
                        <Td className="whitespace-nowrap">
                          <div className="flex items-center gap-2">
                            <AddressDisplay
                              value={role.owner}
                              href={`${blockExplorer}/address/${role.owner}`}
                              className="text-info"
                            />
                            {ownerLabel && <Badge size="sm">{ownerLabel}</Badge>}
                          </div>
                        </Td>
                        <Td className="whitespace-nowrap">
                          {role.targetContract !== '0x0000000000000000000000000000000000000000' ? (
                            <div className="flex items-center gap-2">
                              <AddressDisplay
                                value={role.targetContract}
                                href={`${blockExplorer}/address/${role.targetContract}`}
                                className="text-info"
                              />
                              {targetLabel && <Badge size="sm">{targetLabel}</Badge>}
                            </div>
                          ) : (
                            <span className="text-on-surface-variant/80">—</span>
                          )}
                        </Td>
                        <Td className="whitespace-nowrap">
                          <div className="flex items-center gap-2">
                            <AddressDisplay
                              value={role.accessController}
                              href={`${blockExplorer}/address/${role.accessController}`}
                              className="text-info"
                            />
                            {controllerLabel && <Badge size="sm">{controllerLabel}</Badge>}
                          </div>
                        </Td>
                        <Td className="whitespace-nowrap">
                          <Badge tone={role.active ? 'success' : 'danger'} size="sm">
                            {role.active ? 'Active' : 'Inactive'}
                          </Badge>
                        </Td>
                        <Td className="whitespace-nowrap text-on-surface-variant tabular-nums">
                          {formatTimestamp(role.createdTimestamp)}
                        </Td>
                        <Td className="whitespace-nowrap">
                          {lastEvent ? (
                            <div className="text-sm">
                              <div className="text-on-surface-variant">
                                {lastEvent.action === 'GRANT_ROLE' ? 'Granted' : 'Revoked'}
                              </div>
                              <AddressDisplay
                                value={lastEvent.hash}
                                href={`${blockExplorer}/tx/${lastEvent.hash}`}
                                className="text-info text-xs"
                              />
                              <div className="text-on-surface-variant/80 text-xs tabular-nums">
                                {formatTimestamp(lastEvent.timestamp)}
                              </div>
                            </div>
                          ) : (
                            <span className="text-on-surface-variant/80">—</span>
                          )}
                        </Td>
                      </Tr>
                    )
                  })
                )}
              </TBody>
            </Table>
          </TableContainer>
        )}
      </div>
    </main>
  )
}
