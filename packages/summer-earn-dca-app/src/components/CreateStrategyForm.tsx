'use client'

import { useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Address } from 'viem'
import { useAccount } from 'wagmi'

import { DualAmountInput } from '@/components/DualAmountInput'
import { FeedPriceDisplay } from '@/components/FeedPriceDisplay'
import { Permit2ApprovalSteps } from '@/components/Permit2ApprovalSteps'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardTitle } from '@/components/ui/Card'
import { Field, TextInput } from '@/components/ui/Field'
import { type ActiveFleet,useActiveFleets } from '@/hooks/useActiveFleets'
import { useDcaStrategyActions } from '@/hooks/useDcaStrategyActions'
import { usePermit2Approval } from '@/hooks/usePermit2Approval'
import { shortAddress } from '@/lib/format'
import { buildCreateTuple } from '@/lib/strategy/encode'
import { INTERVAL_PRESETS, validateInterval } from '@/lib/strategy/intervals'
import type { ChainId } from '@/types/chain'

interface CreateStrategyFormProps {
  chainId: ChainId
}

export function CreateStrategyForm({ chainId }: CreateStrategyFormProps) {
  const router = useRouter()
  const { address } = useAccount()

  const fleetsQuery = useActiveFleets(chainId)
  const fleets = useMemo<ActiveFleet[]>(() => fleetsQuery.data ?? [], [fleetsQuery.data])

  const [sourceFleetAddress, setSourceFleetAddress] = useState<Address | ''>('')
  const [targetFleetAddress, setTargetFleetAddress] = useState<Address | ''>('')
  const [tradeAmountShares, setTradeAmountShares] = useState<bigint>(0n)
  const [intervalSeconds, setIntervalSeconds] = useState<bigint>(INTERVAL_PRESETS[0]!.seconds)
  const [slippageBps, setSlippageBps] = useState<bigint>(50n) // 0.5%
  const [maxPriceStr, setMaxPriceStr] = useState('')
  const [minPriceStr, setMinPriceStr] = useState('')
  const [endDateStr, setEndDateStr] = useState('')
  const [maxTradesStr, setMaxTradesStr] = useState('')

  const sourceFleet = useMemo<ActiveFleet | undefined>(
    () => fleets.find((f) => f.address === sourceFleetAddress),
    [fleets, sourceFleetAddress],
  )
  const targetFleet = useMemo<ActiveFleet | undefined>(
    () => fleets.find((f) => f.address === targetFleetAddress),
    [fleets, targetFleetAddress],
  )

  const intervalValidation = validateInterval(intervalSeconds)
  const endDateUnix = endDateStr ? BigInt(Math.floor(new Date(endDateStr).getTime() / 1000)) : 0n
  const maxTrades = maxTradesStr ? BigInt(maxTradesStr) : 0n

  // Feed values use the feed's own decimals — most Chainlink USD feeds are 8.
  // We accept the user-typed value at 8 decimals and round.
  const maxPrice = maxPriceStr ? BigInt(Math.round(parseFloat(maxPriceStr) * 1e8)) : 0n
  const minPrice = minPriceStr ? BigInt(Math.round(parseFloat(minPriceStr) * 1e8)) : 0n

  const missingFeed =
    (sourceFleet && !sourceFleet.feed) || (targetFleet && !targetFleet.feed)
  const sameFleet =
    sourceFleet && targetFleet && sourceFleet.address === targetFleet.address

  const formOk =
    Boolean(address) &&
    Boolean(sourceFleet?.feed) &&
    Boolean(targetFleet?.feed) &&
    !sameFleet &&
    tradeAmountShares > 0n &&
    intervalValidation.ok &&
    slippageBps <= 10_000n &&
    maxTrades > 0n &&
    endDateUnix > 0n

  const permit2 = usePermit2Approval({
    chainId,
    sourceVault: sourceFleet?.address,
    requiredShares: tradeAmountShares,
  })

  const actions = useDcaStrategyActions({
    chainId,
    onCreated: (id) => router.push(`/strategy/${id.toString()}`),
  })

  const tuple = useMemo(() => {
    if (!formOk || !address || !sourceFleet?.feed || !targetFleet?.feed) return undefined
    return buildCreateTuple({
      owner: address,
      sourceVault: sourceFleet.address,
      targetVault: targetFleet.address,
      inAsset: sourceFleet.asset.address,
      outAsset: targetFleet.asset.address,
      inAssetFeed: sourceFleet.feed,
      outAssetFeed: targetFleet.feed,
      tradeAmountShares,
      intervalSeconds,
      slippageBps,
      maxPrice,
      minPrice,
      endDateUnix,
      maxTrades,
    })
  }, [
    formOk,
    address,
    sourceFleet,
    targetFleet,
    tradeAmountShares,
    intervalSeconds,
    slippageBps,
    maxPrice,
    minPrice,
    endDateUnix,
    maxTrades,
  ])

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!tuple) return
    actions.createStrategy(tuple)
  }

  return (
    <form onSubmit={onSubmit} className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Source &amp; target vaults</CardTitle>
          {fleetsQuery.isLoading && (
            <span className="text-xs text-surface-400">Loading active fleets…</span>
          )}
        </CardHeader>

        {fleetsQuery.isError && (
          <p className="text-sm text-danger">
            Could not load active fleets: {(fleetsQuery.error as Error).message}
          </p>
        )}

        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <Field
            label="Source fleet (you hold these shares)"
            hint={
              sourceFleet
                ? `Asset: ${sourceFleet.asset.symbol} (${shortAddress(sourceFleet.asset.address)})`
                : 'Pick a vault you have a position in.'
            }
            error={
              sourceFleet && !sourceFleet.feed
                ? `No Chainlink feed mapped for ${sourceFleet.asset.symbol}. Add one to FEED_BY_ASSET_ADDRESS.`
                : undefined
            }
          >
            <FleetSelect
              value={sourceFleetAddress}
              onChange={setSourceFleetAddress}
              fleets={fleets}
              disabled={fleetsQuery.isLoading || fleets.length === 0}
            />
          </Field>

          <Field
            label="Target fleet (receives swap output)"
            hint={
              targetFleet
                ? `Asset: ${targetFleet.asset.symbol} (${shortAddress(targetFleet.asset.address)})`
                : 'Pick the vault to DCA into.'
            }
            error={
              targetFleet && !targetFleet.feed
                ? `No Chainlink feed mapped for ${targetFleet.asset.symbol}. Add one to FEED_BY_ASSET_ADDRESS.`
                : sameFleet
                  ? 'Source and target must differ.'
                  : undefined
            }
          >
            <FleetSelect
              value={targetFleetAddress}
              onChange={setTargetFleetAddress}
              fleets={fleets}
              disabled={fleetsQuery.isLoading || fleets.length === 0}
              excludeAddress={sourceFleetAddress || undefined}
            />
          </Field>
        </div>

        {(sourceFleet?.feed || targetFleet?.feed) && (
          <div className="mt-4 grid grid-cols-1 gap-2 rounded-md border border-surface-700 bg-surface-900/60 p-3 text-xs text-surface-300 md:grid-cols-2">
            <FeedRow
              label="In feed"
              chainId={chainId}
              feed={sourceFleet?.feed}
              asset={sourceFleet?.asset.symbol}
            />
            <FeedRow
              label="Out feed"
              chainId={chainId}
              feed={targetFleet?.feed}
              asset={targetFleet?.asset.symbol}
            />
          </div>
        )}
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Amount per execution</CardTitle>
        </CardHeader>
        <DualAmountInput
          chainId={chainId}
          sourceVault={sourceFleet?.address}
          underlyingDecimals={sourceFleet?.asset.decimals ?? 18}
          underlyingSymbol={sourceFleet?.asset.symbol ?? '—'}
          shareDecimals={sourceFleet?.decimals ?? 18}
          shareSymbol={sourceFleet?.symbol ?? '—'}
          shares={tradeAmountShares}
          onChange={setTradeAmountShares}
        />
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Schedule</CardTitle>
        </CardHeader>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          <Field
            label="Interval"
            error={!intervalValidation.ok ? intervalValidation.reason : undefined}
          >
            <select
              className="rounded-md border border-surface-700 bg-surface-900 px-3 py-2 text-sm text-surface-50 focus:border-primary focus:outline-none"
              value={intervalSeconds.toString()}
              onChange={(e) => setIntervalSeconds(BigInt(e.target.value))}
            >
              {INTERVAL_PRESETS.map((p) => (
                <option key={p.label} value={p.seconds.toString()}>
                  {p.label}
                </option>
              ))}
            </select>
          </Field>
          <Field label="End date">
            <TextInput
              type="datetime-local"
              value={endDateStr}
              onChange={(e) => setEndDateStr(e.target.value)}
            />
          </Field>
          <Field label="Max trades">
            <TextInput
              type="number"
              min={1}
              value={maxTradesStr}
              onChange={(e) => setMaxTradesStr(e.target.value)}
            />
          </Field>
        </div>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Guardrails</CardTitle>
        </CardHeader>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          <Field label="Slippage (bps)" hint="0..10000 — 50 = 0.5%">
            <TextInput
              type="number"
              min={0}
              max={10_000}
              value={slippageBps.toString()}
              onChange={(e) => setSlippageBps(BigInt(e.target.value || '0'))}
            />
          </Field>
          <Field label="Max in-asset price (USD)" hint="0 = no ceiling. Feed scale: 1e8.">
            <TextInput
              type="number"
              step="any"
              value={maxPriceStr}
              onChange={(e) => setMaxPriceStr(e.target.value)}
            />
          </Field>
          <Field label="Min in-asset price (USD)" hint="0 = no floor.">
            <TextInput
              type="number"
              step="any"
              value={minPriceStr}
              onChange={(e) => setMinPriceStr(e.target.value)}
            />
          </Field>
        </div>
      </Card>

      <Permit2ApprovalSteps
        chainId={chainId}
        sourceVault={sourceFleet?.address}
        requiredShares={tradeAmountShares}
      />

      <div className="flex items-center justify-between gap-3">
        <p className="text-xs text-surface-400">
          {missingFeed
            ? 'Pick fleets whose assets have feed mappings to continue.'
            : 'Approvals must complete before the strategy can be created.'}
        </p>
        <Button
          type="submit"
          disabled={!formOk || permit2.step !== 'ready'}
          loading={actions.createTx.isWriting || actions.createTx.isMining}
        >
          Create strategy
        </Button>
      </div>
    </form>
  )
}

function FleetSelect({
  value,
  onChange,
  fleets,
  disabled,
  excludeAddress,
}: {
  value: Address | ''
  onChange: (a: Address | '') => void
  fleets: ActiveFleet[]
  disabled?: boolean
  excludeAddress?: Address
}) {
  return (
    <select
      disabled={disabled}
      value={value}
      onChange={(e) => onChange((e.target.value || '') as Address | '')}
      className="rounded-md border border-surface-700 bg-surface-900 px-3 py-2 text-sm text-surface-50 focus:border-primary focus:outline-none disabled:opacity-60"
    >
      <option value="">Select a fleet…</option>
      {fleets
        .filter((f) => !excludeAddress || f.address !== excludeAddress)
        .map((f) => (
          <option key={f.address} value={f.address}>
            {f.symbol} — {f.asset.symbol} ({shortAddress(f.address)})
          </option>
        ))}
    </select>
  )
}

function FeedRow({
  label,
  feed,
  asset,
  chainId,
}: {
  label: string
  feed: Address | undefined
  asset: string | undefined
  chainId: ChainId
}) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="uppercase tracking-wide text-surface-500">{label}</span>
      <span className="flex flex-col items-end gap-0.5 text-right">
        <span className="text-surface-200">
          {feed ? (
            <>
              {asset}/USD <span className="text-surface-500">{shortAddress(feed)}</span>
            </>
          ) : (
            <span className="text-warning">unmapped</span>
          )}
        </span>
        {feed && <FeedPriceDisplay chainId={chainId} feed={feed} symbol={asset} />}
      </span>
    </div>
  )
}
