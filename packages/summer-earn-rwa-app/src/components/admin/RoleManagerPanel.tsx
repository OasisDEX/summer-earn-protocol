'use client'

import { useMemo, useState } from 'react'
import { isAddress } from 'viem'
import { useAccount } from 'wagmi'

import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import { Field, TextInput } from '@/components/ui/Field'
import { Pill } from '@/components/ui/Pill'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useAccess } from '@/hooks/useAccess'
import { useRoleActions } from '@/hooks/useRoleActions'
import { useRolesForInstitution } from '@/hooks/useRolesForInstitution'
import {
  ADMIRALS_QUARTERS_ROLE,
  DECAY_CONTROLLER_ROLE,
  FOUNDATION_ROLE,
  generateContractSpecificRole,
  GOVERNOR_ROLE,
  GUARDIAN_ROLE,
  SUPER_KEEPER_ROLE,
  WHITELIST_MANAGER_ROLE,
} from '@/lib/access/roleHashes'
import { formatUnixDate, shortAddress } from '@/lib/format'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
  institutionSubgraphId?: string
}

const ROLE_OPTIONS: Array<{
  label: string
  hash: `0x${string}` | 'CONTRACT_KEEPER' | 'CONTRACT_CURATOR'
}> = [
  { label: 'GOVERNOR_ROLE', hash: GOVERNOR_ROLE },
  { label: 'SUPER_KEEPER_ROLE', hash: SUPER_KEEPER_ROLE },
  { label: 'GUARDIAN_ROLE', hash: GUARDIAN_ROLE },
  { label: 'WHITELIST_MANAGER_ROLE', hash: WHITELIST_MANAGER_ROLE },
  { label: 'DECAY_CONTROLLER_ROLE', hash: DECAY_CONTROLLER_ROLE },
  { label: 'ADMIRALS_QUARTERS_ROLE', hash: ADMIRALS_QUARTERS_ROLE },
  { label: 'FOUNDATION_ROLE', hash: FOUNDATION_ROLE },
  { label: 'KEEPER_ROLE (this fleet)', hash: 'CONTRACT_KEEPER' },
  { label: 'CURATOR_ROLE (this fleet)', hash: 'CONTRACT_CURATOR' },
]

export function RoleManagerPanel({ institution, fleet, institutionSubgraphId }: Props) {
  const { address } = useAccount()
  const access = useAccess({ institution, fleet, account: address })
  const actions = useRoleActions({
    pamAddress: institution.protocolAccessManager,
    chainId: institution.chainId,
  })
  const { roles, loading } = useRolesForInstitution(
    institutionSubgraphId ?? '',
    institution.chainId,
  )

  const [selected, setSelected] = useState<(typeof ROLE_OPTIONS)[number]['hash']>(GOVERNOR_ROLE)
  const [account, setAccount] = useState('')
  const accountValid = isAddress(account.trim())
  const targetHash = useMemo<`0x${string}`>(() => {
    if (selected === 'CONTRACT_KEEPER')
      return generateContractSpecificRole('KEEPER_ROLE', fleet.fleetCommander)
    if (selected === 'CONTRACT_CURATOR')
      return generateContractSpecificRole('CURATOR_ROLE', fleet.fleetCommander)
    return selected
  }, [selected, fleet.fleetCommander])

  const disabled = !access.isGovernor

  return (
    <>
      <Card>
        <CardHeader>
          <div>
            <CardTitle>Grant / revoke roles</CardTitle>
            <CardSub>Governor-only. Operates on ProtocolAccessManagerV2 directly.</CardSub>
          </div>
        </CardHeader>

        {disabled && (
          <div className="mb-6 rounded-md border border-dashed border-[var(--warning)] p-3 text-xs text-[var(--warning)]">
            Connected wallet lacks GOVERNOR_ROLE.
          </div>
        )}

        <div className="grid gap-4 md:grid-cols-2">
          <Field label="Role">
            <select
              value={selected}
              onChange={(e) => setSelected(e.target.value as typeof selected)}
              className="w-full rounded-md border border-[var(--border)] bg-[var(--bg-elev)] px-3.5 py-3 text-sm text-[var(--text)] outline-none focus:border-[var(--pink)] focus:shadow-[0_0_0_3px_var(--pink-soft)]"
            >
              {ROLE_OPTIONS.map((opt) => (
                <option key={opt.label} value={opt.hash}>
                  {opt.label}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Account">
            <TextInput
              value={account}
              onChange={(e) => setAccount(e.target.value)}
              placeholder="0x…"
            />
          </Field>
        </div>

        <div className="mt-2 font-mono text-xs text-[var(--text-3)]">Role hash: {targetHash}</div>

        <div className="mt-4 flex gap-2">
          <Button
            disabled={disabled || !accountValid || actions.pending.grant}
            loading={actions.pending.grant}
            onClick={() =>
              actions
                .grantRole(targetHash, account.trim() as `0x${string}`)
                .then(() => setAccount(''))
            }
          >
            Grant
          </Button>
          <Button
            variant="danger"
            disabled={disabled || !accountValid || actions.pending.revoke}
            onClick={() =>
              actions
                .revokeRole(targetHash, account.trim() as `0x${string}`)
                .then(() => setAccount(''))
            }
          >
            Revoke
          </Button>
        </div>
      </Card>

      <Card className="mt-6">
        <CardHeader>
          <div>
            <CardTitle>Active role grants</CardTitle>
            <CardSub>
              From v2 subgraph ·{' '}
              {institutionSubgraphId ? 'institution scope' : 'institutionId unknown'}
            </CardSub>
          </div>
        </CardHeader>
        {!institutionSubgraphId ? (
          <div className="text-sm text-[var(--text-3)]">
            Institution subgraph id not resolved yet — the registry hash is needed. Use the form
            above; the table will populate once the indexer surfaces this institution.
          </div>
        ) : loading ? (
          <div className="h-24 animate-pulse rounded-lg bg-[var(--surface-2)]" />
        ) : roles.length === 0 ? (
          <div className="text-sm text-[var(--text-3)]">No active roles indexed.</div>
        ) : (
          <div className="divide-y divide-[var(--border-faint)] text-xs">
            {roles.map((r) => (
              <div key={r.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
                <div>
                  <div className="font-medium text-sm">{r.name}</div>
                  <div className="font-mono text-[var(--text-3)]">{r.owner}</div>
                  {r.targetContract &&
                    r.targetContract !== '0x0000000000000000000000000000000000000000' && (
                      <div className="font-mono text-[var(--text-4)]">
                        target {shortAddress(r.targetContract)}
                      </div>
                    )}
                </div>
                <div className="flex items-center gap-2">
                  <Pill variant="active" dot={false}>
                    active
                  </Pill>
                  <span className="font-mono text-[var(--text-3)]">
                    {formatUnixDate(BigInt(r.createdTimestamp))}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>
    </>
  )
}
