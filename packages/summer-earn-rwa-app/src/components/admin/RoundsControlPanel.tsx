'use client'

import { useMemo, useState } from 'react'
import { useAccount } from 'wagmi'

import { RoundStateBadge } from '@/components/rounds/RoundStateBadge'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import { Field, TextInput } from '@/components/ui/Field'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useAccess } from '@/hooks/useAccess'
import { useGovernorActions } from '@/hooks/useGovernorActions'
import { useKeeperActions } from '@/hooks/useKeeperActions'
import { useRounds } from '@/hooks/useRounds'
import { useRoundsVaultState } from '@/hooks/useRoundsVaultState'
import { formatDecimalOutput, parseDecimalInput } from '@/lib/format'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
}

export function RoundsControlPanel({ institution, fleet }: Props) {
  const inputAddr = fleet.roundsVaultInput
  const outputAddr = fleet.roundsVaultOutput

  return (
    <>
      {inputAddr && (
        <VaultControls
          institution={institution}
          fleet={fleet}
          roundsVaultAddress={inputAddr}
          label="Input vault"
          flavor="input"
        />
      )}
      {outputAddr && (
        <VaultControls
          institution={institution}
          fleet={fleet}
          roundsVaultAddress={outputAddr}
          label="Output vault"
          flavor="output"
        />
      )}
    </>
  )
}

function VaultControls({
  institution,
  fleet,
  roundsVaultAddress,
  label,
  flavor,
}: {
  institution: Institution
  fleet: InstitutionFleet
  roundsVaultAddress: `0x${string}`
  label: string
  flavor: 'input' | 'output'
}) {
  const { address } = useAccount()
  const access = useAccess({ institution, fleet, account: address })
  const keeper = useKeeperActions({ roundsVaultAddress, chainId: institution.chainId })
  const governor = useGovernorActions({ roundsVaultAddress, chainId: institution.chainId })
  const { currentRound, roundState, minPositionSize } = useRoundsVaultState({
    roundsVaultAddress,
    chainId: institution.chainId,
  })
  const { rounds, roundsVault } = useRounds({ roundsVaultAddress, chainId: institution.chainId })

  const canKeeper = flavor === 'input' ? access.canKeeperInput : access.canKeeperOutput
  const canGovernor = access.isGovernor

  const settling = useMemo(() => rounds.filter((r) => r.state === 'IN_SETTLEMENT'), [rounds])
  const rolledBack = useMemo(() => rounds.filter((r) => r.state === 'ROLLED_BACK'), [rounds])
  const [batchPicked, setBatchPicked] = useState<Set<string>>(new Set())

  const [minStr, setMinStr] = useState('')
  const underlyingDecimals = roundsVault?.underlyingToken.decimals ?? 18
  const parsedMin = parseDecimalInput(minStr, underlyingDecimals)

  function toggle(id: string) {
    setBatchPicked((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const pickedIds = settling.filter((r) => batchPicked.has(r.id)).map((r) => BigInt(r.roundId))

  return (
    <Card className="mb-6">
      <CardHeader>
        <div>
          <CardTitle>{label}</CardTitle>
          <CardSub>
            {roundsVaultAddress} · current round{' '}
            <span className="font-mono">{currentRound?.toString() ?? '—'}</span>
          </CardSub>
        </div>
        <RoundStateBadge state={roundState} short />
      </CardHeader>

      <div className="space-y-6">
        <div className="rounded-md border border-[var(--border-faint)] bg-[var(--surface-2)] p-4">
          <div className="text-xs text-[var(--text-3)]">Pending settlement amount</div>
          <div className="mt-1 font-mono text-lg">
            {roundsVault
              ? `${formatDecimalOutput(BigInt(roundsVault.pendingSettlementAmount), roundsVault.underlyingToken.decimals)} ${roundsVault.underlyingToken.symbol}`
              : '—'}
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          <Button
            disabled={!canKeeper || keeper.pending.nextRound}
            loading={keeper.pending.nextRound}
            onClick={() => keeper.nextRound()}
            title={
              !canKeeper ? 'Requires KEEPER_ROLE on this vault or SUPER_KEEPER_ROLE' : undefined
            }
          >
            Close current round (nextRound)
          </Button>
        </div>

        <div>
          <div className="section-title">Rounds in settlement</div>
          {settling.length === 0 ? (
            <div className="text-sm text-[var(--text-3)]">Nothing waiting for settlement.</div>
          ) : (
            <>
              <div className="divide-y divide-[var(--border-faint)]">
                {settling.map((r) => (
                  <div key={r.id} className="flex items-center justify-between py-2 text-sm">
                    <label className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        checked={batchPicked.has(r.id)}
                        onChange={() => toggle(r.id)}
                      />
                      <span className="font-mono text-[var(--text-3)]">#{r.roundId}</span>
                    </label>
                    <Button
                      size="sm"
                      variant="secondary"
                      disabled={!canKeeper || keeper.pending.settle}
                      loading={keeper.pending.settle}
                      onClick={() => keeper.setRoundSettled(BigInt(r.roundId))}
                    >
                      Settle
                    </Button>
                  </div>
                ))}
              </div>
              <div className="mt-3">
                <Button
                  disabled={!canKeeper || pickedIds.length === 0 || keeper.pending.settle}
                  loading={keeper.pending.settle}
                  onClick={() => keeper.setRoundSettledBatch(pickedIds)}
                >
                  Settle selected ({pickedIds.length})
                </Button>
              </div>
            </>
          )}
        </div>

        <div>
          <div className="section-title">Retry / rollback</div>
          {rolledBack.length === 0 ? (
            <div className="text-sm text-[var(--text-3)]">No rolled-back rounds.</div>
          ) : (
            <div className="divide-y divide-[var(--border-faint)]">
              {rolledBack.map((r) => (
                <div key={r.id} className="flex items-center justify-between py-2 text-sm">
                  <span className="font-mono text-[var(--text-3)]">#{r.roundId}</span>
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={!canKeeper || keeper.pending.retry}
                    onClick={() => keeper.retryRound(BigInt(r.roundId))}
                  >
                    Retry
                  </Button>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="border-t border-[var(--border-faint)] pt-6">
          <div className="section-title">Governor controls</div>
          <div className="space-y-4">
            <Field
              label="Minimum position size"
              hint={
                minPositionSize !== undefined
                  ? `Current: ${formatDecimalOutput(minPositionSize, underlyingDecimals)}`
                  : undefined
              }
            >
              <div className="flex gap-2">
                <TextInput
                  value={minStr}
                  onChange={(e) => setMinStr(e.target.value)}
                  placeholder="0"
                />
                <Button
                  disabled={!canGovernor || governor.pending.minSize}
                  loading={governor.pending.minSize}
                  onClick={() => governor.setMinPositionSize(parsedMin)}
                >
                  Set
                </Button>
              </div>
            </Field>
            <div>
              <div className="mb-2 text-xs text-[var(--text-3)]">
                Emergency rollback (active when a round is stuck in settlement). Use only when the
                off-chain settlement cannot succeed.
              </div>
              {settling.length === 0 ? (
                <div className="text-sm text-[var(--text-3)]">Nothing to rollback.</div>
              ) : (
                <div className="divide-y divide-[var(--border-faint)]">
                  {settling.map((r) => (
                    <div
                      key={`rb-${r.id}`}
                      className="flex items-center justify-between py-2 text-sm"
                    >
                      <span className="font-mono text-[var(--text-3)]">#{r.roundId}</span>
                      <Button
                        size="sm"
                        variant="danger"
                        disabled={!canGovernor || governor.pending.rollback}
                        onClick={() => governor.emergencyRollbackRound(BigInt(r.roundId))}
                      >
                        Rollback
                      </Button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </Card>
  )
}
