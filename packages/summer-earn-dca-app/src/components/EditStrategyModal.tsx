'use client'

import { useMemo, useState } from 'react'
import { type Address, parseUnits } from 'viem'

import { DualAmountInput } from '@/components/DualAmountInput'
import { Button } from '@/components/ui/Button'
import { Field, TextInput } from '@/components/ui/Field'
import { Modal } from '@/components/ui/Modal'
import { useDcaStrategyActions } from '@/hooks/useDcaStrategyActions'
import { formatDecimalOutput } from '@/lib/format'
import { computeCommitment } from '@/lib/strategy/commitment'
import { INTERVAL_PRESETS, validateInterval } from '@/lib/strategy/intervals'
import type { ChainId } from '@/types/chain'
import type { StrategyConfigTuple } from '@/types/strategy'

interface EditStrategyModalProps {
  open: boolean
  onClose: () => void
  chainId: ChainId
  strategyId: bigint
  oldConfig: StrategyConfigTuple
  inSym: string
  outSym: string
  shareSym: string
  inDecimals: number
  shareDecimals: number
}

// Only the contract-mutable fields are exposed. Owner / vaults / assets /
// feeds are immutable — editing those is a new strategy, not an edit.
export function EditStrategyModal({
  open,
  onClose,
  chainId,
  strategyId,
  oldConfig,
  inSym,
  outSym,
  shareSym,
  inDecimals,
  shareDecimals,
}: EditStrategyModalProps) {
  const actions = useDcaStrategyActions({
    chainId,
    onMutated: () => onClose(),
  })

  const [tradeAmountShares, setTradeAmountShares] = useState<bigint>(oldConfig.tradeAmount)
  const [intervalSeconds, setIntervalSeconds] = useState<bigint>(oldConfig.interval)
  const [slippageBps, setSlippageBps] = useState<bigint>(oldConfig.slippageBps)
  const [maxPriceStr, setMaxPriceStr] = useState<string>(
    oldConfig.maxPrice === 0n ? '' : formatDecimalOutput(oldConfig.maxPrice, 18, 6),
  )
  const [minPriceStr, setMinPriceStr] = useState<string>(
    oldConfig.minPrice === 0n ? '' : formatDecimalOutput(oldConfig.minPrice, 18, 6),
  )
  const [endDateStr, setEndDateStr] = useState<string>(
    oldConfig.endDate === 0n
      ? ''
      : new Date(Number(oldConfig.endDate) * 1000).toISOString().slice(0, 16),
  )
  const [maxTradesStr, setMaxTradesStr] = useState<string>(oldConfig.maxTrades.toString())

  const safePriceInput = (s: string): bigint => {
    if (!s) return 0n
    try {
      return parseUnits(s, 18)
    } catch {
      return 0n
    }
  }

  const intervalValidation = validateInterval(intervalSeconds)
  const endDateUnix = endDateStr ? BigInt(Math.floor(new Date(endDateStr).getTime() / 1000)) : 0n
  const maxTrades = maxTradesStr ? BigInt(maxTradesStr) : 0n
  const maxPrice = safePriceInput(maxPriceStr)
  const minPrice = safePriceInput(minPriceStr)

  const newConfig = useMemo<StrategyConfigTuple>(
    () => ({
      ...oldConfig,
      tradeAmount: tradeAmountShares,
      interval: intervalSeconds,
      slippageBps,
      maxPrice,
      minPrice,
      endDate: endDateUnix,
      maxTrades,
    }),
    [
      oldConfig,
      tradeAmountShares,
      intervalSeconds,
      slippageBps,
      maxPrice,
      minPrice,
      endDateUnix,
      maxTrades,
    ],
  )

  // editStrategy reverts DuplicateStrategy if the commitment hasn't changed.
  const oldHash = useMemo(() => computeCommitment(oldConfig), [oldConfig])
  const newHash = useMemo(() => computeCommitment(newConfig), [newConfig])
  const noChange = oldHash === newHash

  const submittable =
    !noChange &&
    intervalValidation.ok &&
    tradeAmountShares > 0n &&
    slippageBps <= 10_000n &&
    maxTrades > 0n &&
    endDateUnix > 0n

  const onSubmit = () => {
    if (!submittable) return
    actions.editStrategy(strategyId, oldConfig, newConfig)
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={`Edit strategy ${inSym} → ${outSym}`}
      maxWidth={620}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            onClick={onSubmit}
            disabled={!submittable}
            loading={actions.editTx.isWriting || actions.editTx.isMining}
          >
            {noChange ? 'No changes' : 'Save changes'}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-5">
        <div>
          <div className="mb-2 text-[11px] uppercase tracking-[0.06em] text-[var(--text-3)]">
            Amount per execution
          </div>
          <DualAmountInput
            chainId={chainId}
            sourceVault={oldConfig.sourceVault as Address}
            underlyingDecimals={inDecimals}
            underlyingSymbol={inSym}
            shareDecimals={shareDecimals}
            shareSymbol={shareSym}
            shares={tradeAmountShares}
            onChange={setTradeAmountShares}
          />
        </div>

        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          <Field
            label="Interval"
            error={!intervalValidation.ok ? intervalValidation.reason : undefined}
          >
            <select
              className="rounded-md border border-[var(--border)] bg-[var(--bg-elev)] px-3 py-2 text-sm text-[var(--text)] focus:border-[var(--pink)] focus:outline-none"
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
          <Field
            label={`Max ${outSym} price (${inSym} per ${outSym})`}
            hint={`0 = no ceiling. Skip the trade if 1 ${outSym} would cost more than this in ${inSym}.`}
          >
            <TextInput
              type="number"
              step="any"
              min={0}
              value={maxPriceStr}
              onChange={(e) => setMaxPriceStr(e.target.value)}
            />
          </Field>
          <Field
            label={`Min ${outSym} price (${inSym} per ${outSym})`}
            hint={`0 = no floor. Skip the trade if 1 ${outSym} would cost less than this in ${inSym}.`}
          >
            <TextInput
              type="number"
              step="any"
              min={0}
              value={minPriceStr}
              onChange={(e) => setMinPriceStr(e.target.value)}
            />
          </Field>
        </div>
      </div>
    </Modal>
  )
}
