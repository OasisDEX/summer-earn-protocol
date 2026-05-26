'use client'

import { RoundStateBadge } from '@/components/rounds/RoundStateBadge'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useRounds } from '@/hooks/useRounds'
import { useRoundsVaultState } from '@/hooks/useRoundsVaultState'
import { formatDecimalOutput, formatUnixDate } from '@/lib/format'
import type { SubgraphRoundsVault } from '@/lib/subgraph/types'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
  initialInput: SubgraphRoundsVault | null
  initialOutput: SubgraphRoundsVault | null
}

export function RoundsOverviewClient({ institution, fleet, initialInput, initialOutput }: Props) {
  return (
    <div className="mt-12 grid gap-4 md:grid-cols-2">
      {fleet.roundsVaultInput && (
        <VaultRoundsCard
          chainId={institution.chainId}
          roundsVaultAddress={fleet.roundsVaultInput}
          initialData={initialInput}
          title="Input vault — deposits queue"
          flavor="INPUT"
        />
      )}
      {fleet.roundsVaultOutput && (
        <VaultRoundsCard
          chainId={institution.chainId}
          roundsVaultAddress={fleet.roundsVaultOutput}
          initialData={initialOutput}
          title="Output vault — withdrawals queue"
          flavor="OUTPUT"
        />
      )}
    </div>
  )
}

function VaultRoundsCard({
  chainId,
  roundsVaultAddress,
  initialData,
  title,
  flavor,
}: {
  chainId: Institution['chainId']
  roundsVaultAddress: `0x${string}`
  initialData: SubgraphRoundsVault | null
  title: string
  flavor: 'INPUT' | 'OUTPUT'
}) {
  const { roundsVault, rounds } = useRounds({
    roundsVaultAddress,
    chainId,
    initialData,
  })
  const { currentRound, roundState, minPositionSize, currentRoundSupply } = useRoundsVaultState({
    roundsVaultAddress,
    chainId,
  })

  const underlying = roundsVault?.underlyingToken
  const exchange = roundsVault?.exchangeAssetToken

  return (
    <Card>
      <CardHeader>
        <div>
          <CardTitle>{title}</CardTitle>
          <CardSub>
            {flavor === 'INPUT'
              ? `${underlying?.symbol ?? ''} → ${exchange?.symbol ?? ''}`
              : `${underlying?.symbol ?? ''} → ${exchange?.symbol ?? ''}`}
          </CardSub>
        </div>
        <RoundStateBadge state={roundState} short />
      </CardHeader>

      <div className="grid gap-4 text-sm">
        <div className="flex justify-between">
          <span className="text-[var(--text-3)]">Current round</span>
          <span className="font-mono">{currentRound?.toString() ?? '—'}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-[var(--text-3)]">Round receipt supply</span>
          <span className="font-mono">
            {currentRoundSupply !== undefined && underlying
              ? `${formatDecimalOutput(currentRoundSupply, underlying.decimals)} ${underlying.symbol}`
              : '—'}
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-[var(--text-3)]">Minimum position</span>
          <span className="font-mono">
            {minPositionSize !== undefined && underlying
              ? `${formatDecimalOutput(minPositionSize, underlying.decimals)} ${underlying.symbol}`
              : '—'}
          </span>
        </div>
      </div>

      <div className="mt-6">
        <div className="section-title">Recent rounds</div>
        <div className="divide-y divide-[var(--border-faint)] text-xs">
          {rounds.slice(0, 8).map((r) => (
            <div key={r.id} className="flex items-center justify-between py-2">
              <span className="font-mono text-[var(--text-3)]">#{r.roundId}</span>
              <RoundStateBadge state={r.state} short />
              <span className="font-mono text-[var(--text-3)]">
                {r.settledAt
                  ? formatUnixDate(BigInt(r.settledAt))
                  : r.closedAt
                    ? formatUnixDate(BigInt(r.closedAt))
                    : formatUnixDate(BigInt(r.openedAt))}
              </span>
            </div>
          ))}
          {rounds.length === 0 && (
            <div className="py-2 text-[var(--text-3)]">No rounds yet.</div>
          )}
        </div>
      </div>
    </Card>
  )
}
