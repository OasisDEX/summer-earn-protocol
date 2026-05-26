'use cache'

import Link from 'next/link'

import { ConnectButton } from '@/components/ConnectButton'
import { Topbar } from '@/components/shell/Topbar'
import { Card } from '@/components/ui/Card'
import { Pill } from '@/components/ui/Pill'
import { INSTITUTIONS } from '@/config/institutions'

export default async function InstitutionsPage() {
  return (
    <>
      <Topbar crumbs={[{ label: 'Institutions' }]} actions={<ConnectButton />} />
      <div className="page">
        <h1 className="h1">Institutions</h1>
        <p className="mt-2 text-[var(--text-3)]">
          Institutional rounds-vault fleets indexed by the v2 subgraph.
        </p>

        <div className="mt-8 grid gap-4">
          {INSTITUTIONS.map((inst) => (
            <Link key={inst.slug} href={`/institutions/${inst.slug}`} className="block">
              <Card className="transition hover:border-[var(--border-strong)]">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <div className="h2">{inst.displayName}</div>
                    <div className="mt-1 font-mono text-xs text-[var(--text-3)]">
                      {inst.fleets.length} fleet{inst.fleets.length === 1 ? '' : 's'} ·
                      chainId {inst.chainId}
                    </div>
                  </div>
                  <Pill variant="active">Active</Pill>
                </div>
                <div className="mt-4 grid gap-2">
                  {inst.fleets.map((fleet) => (
                    <div
                      key={fleet.fleetCommander}
                      className="flex items-center justify-between border-t border-[var(--border-faint)] pt-3"
                    >
                      <span className="text-sm">{fleet.label}</span>
                      <span className="font-mono text-xs text-[var(--text-3)]">
                        {fleet.fleetCommander.slice(0, 10)}…{fleet.fleetCommander.slice(-4)}
                      </span>
                    </div>
                  ))}
                </div>
              </Card>
            </Link>
          ))}
        </div>
      </div>
    </>
  )
}
