'use client'

import Link from 'next/link'

import { ArkComposition } from '@/components/fleet/ArkComposition'
import { RebalanceHistory } from '@/components/fleet/RebalanceHistory'
import { RoundsOverviewClient } from '@/components/fleet/RoundsOverviewClient'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import { Stat } from '@/components/ui/Stat'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useFleetArks } from '@/hooks/useFleetArks'
import { useFleetInfo } from '@/hooks/useFleetInfo'
import { formatDecimalOutput, formatLargeNumber } from '@/lib/format'
import type { LoadedFleet } from '@/lib/server/loadFleet'
import type { SubgraphRoundsVault } from '@/lib/subgraph/types'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
  loadedFleet: LoadedFleet
  initialInputRoundsVault: SubgraphRoundsVault | null
  initialOutputRoundsVault: SubgraphRoundsVault | null
}

export function FleetDetailBody({
  institution,
  fleet,
  loadedFleet,
  initialInputRoundsVault,
  initialOutputRoundsVault,
}: Props) {
  const { fleetInfo, loading } = useFleetInfo({
    address: fleet.fleetCommander,
    chainId: institution.chainId,
  })
  const { arks, loading: arksLoading } = useFleetArks({
    fleetAddress: fleet.fleetCommander,
    chainId: institution.chainId,
  })

  const tvl = fleetInfo ? formatLargeNumber(fleetInfo.totalAssets, fleetInfo.assetDecimals) : '—'
  const cap = fleetInfo ? formatLargeNumber(fleetInfo.depositCap, fleetInfo.assetDecimals) : '—'
  const buffer = fleetInfo
    ? formatDecimalOutput(fleetInfo.minimumBufferBalance, fleetInfo.assetDecimals)
    : '—'

  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="h1">{fleet.label}</h1>
          <p className="mt-1 font-mono text-xs text-[var(--text-3)]">{fleet.fleetCommander}</p>
        </div>
        <div className="flex gap-2">
          {fleet.roundsVaultInput && (
            <Link href={`/institutions/${institution.slug}/fleets/${fleet.fleetCommander}/deposit`}>
              <Button>Deposit</Button>
            </Link>
          )}
          {fleet.roundsVaultOutput && (
            <Link
              href={`/institutions/${institution.slug}/fleets/${fleet.fleetCommander}/withdraw`}
            >
              <Button variant="secondary">Withdraw</Button>
            </Link>
          )}
          <Link href={`/institutions/${institution.slug}/fleets/${fleet.fleetCommander}/receipts`}>
            <Button variant="ghost">Receipts</Button>
          </Link>
          <Link href={`/institutions/${institution.slug}/fleets/${fleet.fleetCommander}/admin`}>
            <Button variant="ghost">Admin</Button>
          </Link>
        </div>
      </div>

      <div className="mt-8 grid gap-4 md:grid-cols-3">
        <Stat
          label="TVL"
          value={`${tvl} ${fleetInfo?.assetSymbol ?? ''}`}
          sub={loading ? 'loading…' : undefined}
        />
        <Stat label="Deposit cap" value={`${cap} ${fleetInfo?.assetSymbol ?? ''}`} />
        <Stat label="Minimum buffer" value={`${buffer} ${fleetInfo?.assetSymbol ?? ''}`} />
      </div>

      {(fleet.roundsVaultInput || fleet.roundsVaultOutput) && (
        <RoundsOverviewClient
          institution={institution}
          fleet={fleet}
          initialInput={initialInputRoundsVault}
          initialOutput={initialOutputRoundsVault}
        />
      )}

      <Card className="mt-12">
        <CardHeader>
          <div>
            <CardTitle>Ark composition</CardTitle>
            <CardSub>Buffer + active arks held by this fleet</CardSub>
          </div>
        </CardHeader>
        {arksLoading ? (
          <div className="h-24 animate-pulse rounded-lg bg-[var(--surface-2)]" />
        ) : (
          <ArkComposition
            arks={arks}
            totalAssets={fleetInfo?.totalAssets ?? 0n}
            assetDecimals={fleetInfo?.assetDecimals ?? 6}
            assetSymbol={fleetInfo?.assetSymbol ?? ''}
          />
        )}
      </Card>

      <Card className="mt-6">
        <CardHeader>
          <div>
            <CardTitle>Recent rebalances</CardTitle>
            <CardSub>Last 25 keeper-triggered moves between arks</CardSub>
          </div>
        </CardHeader>
        <RebalanceHistory rebalances={loadedFleet.rebalances} />
      </Card>
    </>
  )
}
