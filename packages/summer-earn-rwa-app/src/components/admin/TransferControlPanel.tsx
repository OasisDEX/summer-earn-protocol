'use client'

import { useAccount, useReadContract } from 'wagmi'

import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import { Pill } from '@/components/ui/Pill'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useAccess } from '@/hooks/useAccess'
import { useFleetTransferActions } from '@/hooks/useFleetTransferActions'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
}

export function TransferControlPanel({ institution, fleet }: Props) {
  const { address } = useAccount()
  const access = useAccess({ institution, fleet, account: address })
  const actions = useFleetTransferActions({
    fleetAddress: fleet.fleetCommander,
    chainId: institution.chainId,
  })

  const transfersRead = useReadContract({
    address: fleet.fleetCommander,
    abi: fleetCommanderAbi,
    functionName: 'transfersEnabled',
  })
  const enabled = transfersRead.data === true

  const disabled = !access.isGovernor

  return (
    <Card>
      <CardHeader>
        <div>
          <CardTitle>Transfer controls</CardTitle>
          <CardSub>
            FleetCommander {fleet.fleetCommander.slice(0, 10)}…{fleet.fleetCommander.slice(-4)} ·
            governor only
          </CardSub>
        </div>
        {transfersRead.isLoading ? (
          <Pill variant="neutral">Loading…</Pill>
        ) : enabled ? (
          <Pill variant="active">Transfers on</Pill>
        ) : (
          <Pill variant="neutral">Transfers off</Pill>
        )}
      </CardHeader>

      {disabled && (
        <div className="mb-6 rounded-md border border-dashed border-[var(--warning)] p-3 text-xs text-[var(--warning)]">
          Connected wallet lacks GOVERNOR_ROLE — the toggle below will fail. Ask a governor to grant
          the role via the Roles tab.
        </div>
      )}

      <div className="mt-6 grid gap-2">
        <Button
          variant={enabled ? 'danger' : 'secondary'}
          disabled={disabled || actions.pending || transfersRead.isLoading}
          loading={actions.pending}
          onClick={() => actions.toggleTransfers().then(() => transfersRead.refetch())}
        >
          {enabled ? 'Disable transfers' : 'Enable transfers'}
        </Button>
      </div>

      <div className="mt-4 rounded-md border border-dashed border-[var(--border)] p-3 text-xs text-[var(--text-3)]">
        Enabling lets holders freely transfer this fleet&apos;s share token; disabling locks
        transfers (the staking-rewards manager is always exempt).
      </div>
    </Card>
  )
}
