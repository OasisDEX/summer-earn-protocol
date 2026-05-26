'use client'

import { useState } from 'react'
import { useAccount } from 'wagmi'

import { ExchangeRateDisplay } from '@/components/rounds/ExchangeRateDisplay'
import { RoundStateBadge } from '@/components/rounds/RoundStateBadge'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useMounted } from '@/hooks/useMounted'
import { useRoundsActions } from '@/hooks/useRoundsActions'
import { useUserReceipts } from '@/hooks/useUserReceipts'
import { formatDecimalOutput } from '@/lib/format'
import { priceFromSubgraph } from '@/lib/rounds/rate'
import type { SubgraphReceipt } from '@/lib/subgraph/types'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
}

export function ReceiptTable({ institution, fleet }: Props) {
  const { address } = useAccount()
  // wagmi resolves the connected address only on the client (from
  // wallet/localStorage state), so SSR sees `undefined` while a returning
  // user's hydrated client sees the real address. Gate the
  // connection-dependent branch behind a post-mount flag so SSR + the first
  // client render both produce the same skeleton, then swap to the real
  // content after hydration.
  const mounted = useMounted()

  const { receipts, loading } = useUserReceipts({
    chainId: institution.chainId,
  })

  // Both Input and Output rounds-vaults under this fleet (a user might hold receipts in either).
  const vaultsForThisFleet = new Set(
    [fleet.roundsVaultInput, fleet.roundsVaultOutput].filter(Boolean).map((a) => a!.toLowerCase()),
  )
  const filtered = receipts.filter((r) => vaultsForThisFleet.has(r.vault.id.toLowerCase()))

  const inputReceipts = filtered.filter((r) => r.vault.flavor === 'INPUT')
  const outputReceipts = filtered.filter((r) => r.vault.flavor === 'OUTPUT')

  return (
    <>
      <ReceiptGroup
        institution={institution}
        title="Input vault receipts"
        sub="USDC deposits queued; redeemable for fleet shares once settled"
        receipts={inputReceipts}
        loading={loading}
        connected={!!address}
        mounted={mounted}
      />
      <ReceiptGroup
        institution={institution}
        title="Output vault receipts"
        sub="Fleet-share withdrawals queued; redeemable for USDC once settled"
        receipts={outputReceipts}
        loading={loading}
        connected={!!address}
        mounted={mounted}
      />
    </>
  )
}

function ReceiptGroup({
  institution,
  title,
  sub,
  receipts,
  loading,
  connected,
  mounted,
}: {
  institution: Institution
  title: string
  sub: string
  receipts: SubgraphReceipt[]
  loading: boolean
  connected: boolean
  mounted: boolean
}) {
  return (
    <Card className="mt-6">
      <CardHeader>
        <div>
          <CardTitle>{title}</CardTitle>
          <CardSub>{sub}</CardSub>
        </div>
      </CardHeader>

      {!mounted ? (
        <div className="h-24 animate-pulse rounded-lg bg-[var(--surface-2)]" />
      ) : !connected ? (
        <div className="text-sm text-[var(--text-3)]">Connect a wallet to view your receipts.</div>
      ) : loading ? (
        <div className="h-24 animate-pulse rounded-lg bg-[var(--surface-2)]" />
      ) : receipts.length === 0 ? (
        <div className="text-sm text-[var(--text-3)]">No active receipts in this queue.</div>
      ) : (
        <div className="divide-y divide-[var(--border-faint)]">
          {receipts.map((r) => (
            <ReceiptRow key={r.id} institution={institution} receipt={r} />
          ))}
        </div>
      )}
    </Card>
  )
}

function ReceiptRow({
  institution,
  receipt,
}: {
  institution: Institution
  receipt: SubgraphReceipt
}) {
  const { address } = useAccount()
  const rvAddr = receipt.vault.id as `0x${string}`
  const actions = useRoundsActions({
    roundsVaultAddress: rvAddr,
    chainId: institution.chainId,
    owner: address,
  })
  const [busy, setBusy] = useState(false)

  const balance = BigInt(receipt.balance)
  const roundId = BigInt(receipt.round.roundId)
  const rate = priceFromSubgraph(receipt.round)
  const underlying = receipt.vault.underlyingToken
  const exchange = receipt.vault.exchangeAssetToken

  async function onCancel() {
    if (!address) return
    setBusy(true)
    try {
      await actions.redeemCurrent(roundId, balance, address)
    } finally {
      setBusy(false)
    }
  }

  async function onClaim() {
    if (!address) return
    setBusy(true)
    try {
      await actions.claimSettled(roundId, balance, address)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex flex-wrap items-center justify-between gap-4 py-4">
      <div className="flex flex-col gap-1">
        <div className="flex items-center gap-2 text-sm">
          <span className="font-mono text-[var(--text-3)]">Round #{receipt.round.roundId}</span>
          <RoundStateBadge state={receipt.round.state} short />
        </div>
        <div className="text-sm">
          <span className="font-mono text-[var(--text)]">
            {formatDecimalOutput(balance, underlying.decimals)} {underlying.symbol}
          </span>
        </div>
        <ExchangeRateDisplay
          rate={rate}
          receiptAmount={balance}
          underlyingDecimals={underlying.decimals}
          exchangeDecimals={exchange.decimals}
          underlyingSymbol={underlying.symbol}
          exchangeSymbol={exchange.symbol}
        />
      </div>
      <div className="flex gap-2">
        {receipt.round.state === 'OPENED' && (
          <Button variant="secondary" loading={busy || actions.pending.redeem} onClick={onCancel}>
            Cancel
          </Button>
        )}
        {receipt.round.state === 'SETTLED' && (
          <Button loading={busy || actions.pending.claim} onClick={onClaim}>
            Claim
          </Button>
        )}
        {receipt.round.state === 'IN_SETTLEMENT' && (
          <span className="text-xs text-[var(--text-3)]">Locked while keeper settles</span>
        )}
      </div>
    </div>
  )
}
