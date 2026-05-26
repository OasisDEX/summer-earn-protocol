'use client'

import { useState } from 'react'
import { isAddress } from 'viem'
import { useAccount } from 'wagmi'

import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import { Field, TextInput } from '@/components/ui/Field'
import { Pill } from '@/components/ui/Pill'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useAccess } from '@/hooks/useAccess'
import { useWhitelistActions } from '@/hooks/useWhitelistActions'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
}

export function WhitelistManagerPanel({ institution, fleet }: Props) {
  const { address } = useAccount()
  const access = useAccess({ institution, fleet, account: address })
  const actions = useWhitelistActions({
    pamAddress: institution.protocolAccessManager,
    contextAddress: fleet.fleetCommander,
    chainId: institution.chainId,
  })

  const [target, setTarget] = useState('')
  const [batch, setBatch] = useState('')
  const targetValid = isAddress(target.trim())

  function parsedBatch(): { addresses: `0x${string}`[]; errors: string[] } {
    const lines = batch
      .split(/[\s,]+/)
      .map((s) => s.trim())
      .filter(Boolean)
    const addresses: `0x${string}`[] = []
    const errors: string[] = []
    for (const line of lines) {
      if (isAddress(line)) addresses.push(line as `0x${string}`)
      else errors.push(line)
    }
    return { addresses, errors }
  }

  const { addresses: batchAddrs, errors: batchErrors } = parsedBatch()
  const disabled = !access.isWhitelistManager && !access.isGovernor

  return (
    <>
      <Card>
        <CardHeader>
          <div>
            <CardTitle>Whitelist controls</CardTitle>
            <CardSub>
              Context = FleetCommander {fleet.fleetCommander.slice(0, 10)}…{fleet.fleetCommander.slice(-4)}
            </CardSub>
          </div>
          {access.isWhitelistOpen ? (
            <Pill variant="paused">Open mode</Pill>
          ) : (
            <Pill variant="completed">Gated</Pill>
          )}
        </CardHeader>

        {disabled && (
          <div className="mb-6 rounded-md border border-dashed border-[var(--warning)] p-3 text-xs text-[var(--warning)]">
            Connected wallet lacks WHITELIST_MANAGER_ROLE — actions below will fail. Ask a
            governor to grant the role via the Roles tab.
          </div>
        )}

        <div className="mt-6 grid gap-2">
          <Button
            variant={access.isWhitelistOpen ? 'danger' : 'secondary'}
            disabled={disabled || actions.pending.open}
            loading={actions.pending.open}
            onClick={() => actions.setWhitelistOpen(!access.isWhitelistOpen).then(() => access.refetch())}
          >
            {access.isWhitelistOpen ? 'Close whitelist' : 'Open whitelist to all'}
          </Button>
        </div>
      </Card>

      <Card className="mt-6">
        <CardHeader>
          <div>
            <CardTitle>Single update</CardTitle>
            <CardSub>setWhitelisted(account, allowed)</CardSub>
          </div>
        </CardHeader>
        <div className="space-y-4">
          <Field label="Account">
            <TextInput
              value={target}
              onChange={(e) => setTarget(e.target.value)}
              placeholder="0x…"
            />
          </Field>
          <div className="flex gap-2">
            <Button
              disabled={disabled || !targetValid || actions.pending.single}
              loading={actions.pending.single}
              onClick={() =>
                actions
                  .setWhitelisted(target.trim() as `0x${string}`, true)
                  .then(() => setTarget(''))
              }
            >
              Whitelist
            </Button>
            <Button
              variant="danger"
              disabled={disabled || !targetValid || actions.pending.single}
              onClick={() =>
                actions
                  .setWhitelisted(target.trim() as `0x${string}`, false)
                  .then(() => setTarget(''))
              }
            >
              Remove
            </Button>
          </div>
        </div>
      </Card>

      <Card className="mt-6">
        <CardHeader>
          <div>
            <CardTitle>Batch update</CardTitle>
            <CardSub>setWhitelistedBatch — max 200 addresses</CardSub>
          </div>
        </CardHeader>
        <div className="space-y-4">
          <Field
            label="Addresses (newline or comma separated)"
            hint={`Parsed: ${batchAddrs.length} valid${batchErrors.length ? `, ${batchErrors.length} invalid` : ''}`}
            error={batchErrors.length ? `Skipping: ${batchErrors.slice(0, 3).join(', ')}…` : undefined}
          >
            <textarea
              value={batch}
              onChange={(e) => setBatch(e.target.value)}
              rows={5}
              className="w-full rounded-md border border-[var(--border)] bg-[var(--bg-elev)] px-3.5 py-3 font-mono text-xs text-[var(--text)] outline-none focus:border-[var(--pink)] focus:shadow-[0_0_0_3px_var(--pink-soft)]"
              placeholder="0x…&#10;0x…&#10;0x…"
            />
          </Field>
          <div className="flex gap-2">
            <Button
              disabled={
                disabled || batchAddrs.length === 0 || batchAddrs.length > 200 || actions.pending.batch
              }
              loading={actions.pending.batch}
              onClick={() =>
                actions
                  .setWhitelistedBatch(batchAddrs, batchAddrs.map(() => true))
                  .then(() => setBatch(''))
              }
            >
              Whitelist all
            </Button>
            <Button
              variant="danger"
              disabled={
                disabled || batchAddrs.length === 0 || batchAddrs.length > 200 || actions.pending.batch
              }
              onClick={() =>
                actions
                  .setWhitelistedBatch(batchAddrs, batchAddrs.map(() => false))
                  .then(() => setBatch(''))
              }
            >
              Remove all
            </Button>
          </div>
        </div>
      </Card>
    </>
  )
}
