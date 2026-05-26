'use client'

import { useMemo, useState } from 'react'
import { useAccount } from 'wagmi'

import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import { Field, TextInput } from '@/components/ui/Field'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useAccess } from '@/hooks/useAccess'
import { useFleetArks } from '@/hooks/useFleetArks'
import { useFleetInfo } from '@/hooks/useFleetInfo'
import { type RebalanceLeg, useFleetRebalanceActions } from '@/hooks/useFleetRebalanceActions'
import { formatDecimalOutput, parseDecimalInput } from '@/lib/format'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
}

export function RebalancePanel({ institution, fleet }: Props) {
  const { address } = useAccount()
  const access = useAccess({ institution, fleet, account: address })
  const { arks } = useFleetArks({
    fleetAddress: fleet.fleetCommander,
    chainId: institution.chainId,
  })
  const { fleetInfo } = useFleetInfo({
    address: fleet.fleetCommander,
    chainId: institution.chainId,
  })
  const rebalance = useFleetRebalanceActions({
    fleetAddress: fleet.fleetCommander,
    chainId: institution.chainId,
  })

  const [fromArk, setFromArk] = useState<string>('')
  const [toArk, setToArk] = useState<string>('')
  const [amountStr, setAmountStr] = useState('')

  const decimals = fleetInfo?.assetDecimals ?? 18
  const symbol = fleetInfo?.assetSymbol ?? ''
  const amount = useMemo(() => parseDecimalInput(amountStr, decimals), [amountStr, decimals])

  const disabled = !access.canRebalance
  const validPair = fromArk && toArk && fromArk !== toArk && amount > 0n

  function onSubmit() {
    if (!validPair) return
    const leg: RebalanceLeg = {
      fromArk: fromArk as `0x${string}`,
      toArk: toArk as `0x${string}`,
      amount,
      boardData: '0x',
      disembarkData: '0x',
    }
    return rebalance.rebalance([leg]).then(() => setAmountStr(''))
  }

  return (
    <Card>
      <CardHeader>
        <div>
          <CardTitle>Rebalance</CardTitle>
          <CardSub>Move assets between active arks · curator or keeper</CardSub>
        </div>
      </CardHeader>

      {disabled && (
        <div className="mb-6 rounded-md border border-dashed border-[var(--warning)] p-3 text-xs text-[var(--warning)]">
          Connected wallet lacks CURATOR_ROLE / KEEPER_ROLE / SUPER_KEEPER_ROLE for this fleet.
        </div>
      )}

      <div className="grid gap-4 md:grid-cols-2">
        <Field label="From ark">
          <select
            value={fromArk}
            onChange={(e) => setFromArk(e.target.value)}
            className="w-full rounded-md border border-[var(--border)] bg-[var(--bg-elev)] px-3.5 py-3 text-sm text-[var(--text)] outline-none focus:border-[var(--pink)] focus:shadow-[0_0_0_3px_var(--pink-soft)]"
          >
            <option value="">—</option>
            {arks.map((ark) => (
              <option key={ark.address} value={ark.address}>
                {ark.isBufferArk ? 'Buffer · ' : ''}
                {ark.name || ark.address.slice(0, 10)} ·{' '}
                {formatDecimalOutput(ark.totalAssets, decimals)} {symbol}
              </option>
            ))}
          </select>
        </Field>
        <Field label="To ark">
          <select
            value={toArk}
            onChange={(e) => setToArk(e.target.value)}
            className="w-full rounded-md border border-[var(--border)] bg-[var(--bg-elev)] px-3.5 py-3 text-sm text-[var(--text)] outline-none focus:border-[var(--pink)] focus:shadow-[0_0_0_3px_var(--pink-soft)]"
          >
            <option value="">—</option>
            {arks.map((ark) => (
              <option key={ark.address} value={ark.address}>
                {ark.isBufferArk ? 'Buffer · ' : ''}
                {ark.name || ark.address.slice(0, 10)}
              </option>
            ))}
          </select>
        </Field>
        <Field label={`Amount (${symbol})`} hint="Empty boardData/disembarkData — simple arks only">
          <TextInput
            value={amountStr}
            onChange={(e) => setAmountStr(e.target.value)}
            placeholder="0"
          />
        </Field>
      </div>

      <div className="mt-6 flex gap-2">
        <Button
          disabled={disabled || !validPair || rebalance.pending}
          loading={rebalance.pending}
          onClick={onSubmit}
        >
          Submit rebalance
        </Button>
      </div>

      <div className="mt-4 rounded-md border border-dashed border-[var(--border)] p-3 text-xs text-[var(--text-3)]">
        For arks that need encoded boardData/disembarkData (WisdomTree, intent-routed arks, etc.)
        use the existing summer-earn-interface rebalance UI. This panel sends empty bytes only.
      </div>
    </Card>
  )
}
