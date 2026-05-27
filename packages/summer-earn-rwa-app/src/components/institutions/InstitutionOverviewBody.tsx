import Link from 'next/link'

import { Card } from '@/components/ui/Card'
import { Pill } from '@/components/ui/Pill'
import { Stat } from '@/components/ui/Stat'
import type { LoadedInstitution } from '@/lib/server/loadInstitution'

interface Props {
  institution: LoadedInstitution
}

export function InstitutionOverviewBody({ institution }: Props) {
  return (
    <>
      <div className="mt-8 grid gap-4 md:grid-cols-3">
        <Stat label="Fleets" value={institution.fleets.length.toString()} />
        <Stat label="Governors" value={institution.governors.length.toString()} />
        <Stat label="Whitelist managers" value={institution.whitelistManagers.length.toString()} />
      </div>

      <h2 className="h2 mt-12">Fleets</h2>
      <div className="mt-4 grid gap-4">
        {institution.fleets.map((fleet) => {
          const pair = fleet.vault?.roundsVaultPair
          const inputRound = pair?.inputVault?.currentRound
          const outputRound = pair?.outputVault?.currentRound

          return (
            <Link
              key={fleet.fleetCommander}
              href={`/institutions/${institution.slug}/fleets/${fleet.fleetCommander}`}
              className="block"
            >
              <Card className="transition hover:border-[var(--border-strong)]">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <div className="h2">{fleet.label}</div>
                      {fleet.vault?.isWhitelistOpen ? (
                        <Pill variant="paused" dot={false}>
                          Whitelist open
                        </Pill>
                      ) : (
                        <Pill variant="completed" dot={false}>
                          Whitelist gated
                        </Pill>
                      )}
                    </div>
                    <div className="mt-1 font-mono text-xs text-[var(--text-3)]">
                      {fleet.vault?.name ?? '—'} · {fleet.vault?.symbol ?? ''}
                    </div>
                  </div>
                  <div className="text-right text-xs text-[var(--text-3)]">
                    <div>
                      Input round{' '}
                      <span className="font-mono text-[var(--text)]">{inputRound ?? '—'}</span>
                    </div>
                    <div>
                      Output round{' '}
                      <span className="font-mono text-[var(--text)]">{outputRound ?? '—'}</span>
                    </div>
                  </div>
                </div>
                <div className="mt-4 grid gap-2 text-xs text-[var(--text-3)] md:grid-cols-3">
                  <div>
                    <span className="text-[var(--text-4)]">FleetCommander</span>
                    <div className="font-mono text-[var(--text-2)]">{fleet.fleetCommander}</div>
                  </div>
                  <div>
                    <span className="text-[var(--text-4)]">RoundsVault Input</span>
                    <div className="font-mono text-[var(--text-2)]">
                      {fleet.roundsVaultInput ?? '—'}
                    </div>
                  </div>
                  <div>
                    <span className="text-[var(--text-4)]">RoundsVault Output</span>
                    <div className="font-mono text-[var(--text-2)]">
                      {fleet.roundsVaultOutput ?? '—'}
                    </div>
                  </div>
                </div>
              </Card>
            </Link>
          )
        })}
      </div>
    </>
  )
}
