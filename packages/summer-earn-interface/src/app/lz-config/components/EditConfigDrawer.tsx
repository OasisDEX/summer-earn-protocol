'use client'

import { useEffect, useMemo, useState } from 'react'
import { type Address, isAddress } from 'viem'

import { useOnChainRouteState } from '../hooks/useOnChainRouteState'
import { addressToBytes32 } from '../lib/encodeDecode'
import type {
  ChainName,
  DesiredRouteConfig,
  ExecutorConfig,
  OAppKind,
  PendingEdit,
  UlnConfig,
} from '../lib/types'

interface Props {
  sourceChain: ChainName
  oApp: OAppKind
  oAppAddress: Address
  remoteChain: ChainName
  desired: DesiredRouteConfig | null
  onClose: () => void
  onSubmit: (edits: PendingEdit[]) => void
}

interface UlnFormState {
  confirmations: string
  requiredDVNCount: string
  optionalDVNCount: string
  optionalDVNThreshold: string
  requiredDVNs: string
  optionalDVNs: string
}

function ulnToFormState(uln: UlnConfig | null | undefined): UlnFormState {
  if (!uln) {
    return {
      confirmations: '15',
      requiredDVNCount: '0',
      optionalDVNCount: '0',
      optionalDVNThreshold: '0',
      requiredDVNs: '',
      optionalDVNs: '',
    }
  }
  return {
    confirmations: String(uln.confirmations),
    requiredDVNCount: String(uln.requiredDVNCount),
    optionalDVNCount: String(uln.optionalDVNCount),
    optionalDVNThreshold: String(uln.optionalDVNThreshold),
    requiredDVNs: (uln.requiredDVNs ?? []).join('\n'),
    optionalDVNs: (uln.optionalDVNs ?? []).join('\n'),
  }
}

interface UlnParseResult {
  uln: UlnConfig | null
  error: string | null
}

function parseUlnFormState(form: UlnFormState): UlnParseResult {
  let confirmations: bigint
  try {
    confirmations = BigInt(form.confirmations.trim() || '0')
    if (confirmations < 0n) return { uln: null, error: 'confirmations must be >= 0' }
  } catch {
    return { uln: null, error: 'confirmations must be an integer' }
  }

  const requiredDVNCount = Number(form.requiredDVNCount.trim() || '0')
  const optionalDVNCount = Number(form.optionalDVNCount.trim() || '0')
  const optionalDVNThreshold = Number(form.optionalDVNThreshold.trim() || '0')

  if (!Number.isInteger(requiredDVNCount) || requiredDVNCount < 0) {
    return { uln: null, error: 'requiredDVNCount must be a non-negative integer' }
  }
  if (!Number.isInteger(optionalDVNCount) || optionalDVNCount < 0) {
    return { uln: null, error: 'optionalDVNCount must be a non-negative integer' }
  }
  if (!Number.isInteger(optionalDVNThreshold) || optionalDVNThreshold < 0) {
    return { uln: null, error: 'optionalDVNThreshold must be a non-negative integer' }
  }
  if (optionalDVNThreshold > optionalDVNCount) {
    return { uln: null, error: 'optionalDVNThreshold must be <= optionalDVNCount' }
  }

  const requiredDVNs = form.requiredDVNs
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
  const optionalDVNs = form.optionalDVNs
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0)

  for (const a of requiredDVNs) {
    if (!isAddress(a)) return { uln: null, error: `invalid required DVN address: ${a}` }
  }
  for (const a of optionalDVNs) {
    if (!isAddress(a)) return { uln: null, error: `invalid optional DVN address: ${a}` }
  }

  if (requiredDVNs.length !== requiredDVNCount) {
    return {
      uln: null,
      error: `requiredDVNCount (${requiredDVNCount}) does not match required DVN list length (${requiredDVNs.length})`,
    }
  }
  if (optionalDVNs.length !== optionalDVNCount) {
    return {
      uln: null,
      error: `optionalDVNCount (${optionalDVNCount}) does not match optional DVN list length (${optionalDVNs.length})`,
    }
  }

  const sortedRequired = [...requiredDVNs].sort((a, b) =>
    a.toLowerCase().localeCompare(b.toLowerCase()),
  ) as readonly Address[]
  const sortedOptional = [...optionalDVNs].sort((a, b) =>
    a.toLowerCase().localeCompare(b.toLowerCase()),
  ) as readonly Address[]

  return {
    uln: {
      confirmations,
      requiredDVNCount,
      optionalDVNCount,
      optionalDVNThreshold,
      requiredDVNs: sortedRequired,
      optionalDVNs: sortedOptional,
    },
    error: null,
  }
}

const inputCls =
  'w-full bg-white/5 border border-white/10 rounded-lg py-2 px-3 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all text-white placeholder-slate-500'

function Field({
  label,
  error,
  children,
}: {
  label: string
  error?: string | null
  children: React.ReactNode
}) {
  return (
    <div className="mb-3">
      <label className="block text-xs uppercase tracking-wider text-slate-500 mb-1">{label}</label>
      {children}
      {error ? <div className="text-red-400 text-xs mt-1">{error}</div> : null}
    </div>
  )
}

function SectionToggle({
  title,
  included,
  onToggle,
  children,
}: {
  title: string
  included: boolean
  onToggle: (v: boolean) => void
  children?: React.ReactNode
}) {
  return (
    <div className="mb-4 rounded-lg border border-white/10 bg-white/[0.02]">
      <label className="flex items-center gap-3 p-3 cursor-pointer">
        <input
          type="checkbox"
          checked={included}
          onChange={(e) => onToggle(e.target.checked)}
          className="h-4 w-4 accent-primary"
        />
        <span className="text-sm font-medium text-white">{title}</span>
        <span className="ml-auto text-xs uppercase tracking-wider text-slate-500">
          {included ? 'included' : 'skip'}
        </span>
      </label>
      {included ? <div className="px-3 pb-3 pt-1 border-t border-white/5">{children}</div> : null}
    </div>
  )
}

export function EditConfigDrawer({
  sourceChain,
  oApp,
  oAppAddress,
  remoteChain,
  desired,
  onClose,
  onSubmit,
}: Props) {
  const { data: onChain, isLoading } = useOnChainRouteState(sourceChain, oApp, remoteChain)

  // peer
  const [includePeer, setIncludePeer] = useState(false)
  const [peerInput, setPeerInput] = useState<string>(desired?.peerAddress ?? '')

  // send lib
  const [includeSendLib, setIncludeSendLib] = useState(false)
  const [sendLibInput, setSendLibInput] = useState<string>(desired?.sendLib ?? '')

  // receive lib
  const [includeReceiveLib, setIncludeReceiveLib] = useState(false)
  const [receiveLibInput, setReceiveLibInput] = useState<string>(desired?.receiveLib ?? '')
  const [gracePeriodInput, setGracePeriodInput] = useState<string>('0')

  // send config
  const [includeSendConfig, setIncludeSendConfig] = useState(false)
  const [executorAddrInput, setExecutorAddrInput] = useState<string>(
    desired?.executor.executorAddress ?? '',
  )
  const [executorSizeInput, setExecutorSizeInput] = useState<string>(
    String(desired?.executor.maxMessageSize ?? 10000),
  )
  const [sendUlnForm, setSendUlnForm] = useState<UlnFormState>(ulnToFormState(desired?.uln ?? null))

  // receive config
  const [includeReceiveConfig, setIncludeReceiveConfig] = useState(false)
  const [receiveUlnForm, setReceiveUlnForm] = useState<UlnFormState>(
    ulnToFormState(desired?.uln ?? null),
  )

  // submission error (e.g. missing send lib for setSendConfig)
  const [submitError, setSubmitError] = useState<string | null>(null)

  // close on Escape
  useEffect(() => {
    function handler(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  const eid = useMemo(() => desired?.eid ?? null, [desired])

  // validation
  const peerError = useMemo<string | null>(() => {
    if (!includePeer) return null
    const v = peerInput.trim()
    if (!v) return 'peer address required'
    if (!isAddress(v)) return 'invalid address'
    return null
  }, [includePeer, peerInput])

  const sendLibError = useMemo<string | null>(() => {
    if (!includeSendLib) return null
    const v = sendLibInput.trim()
    if (!v) return 'send library address required'
    if (!isAddress(v)) return 'invalid address'
    return null
  }, [includeSendLib, sendLibInput])

  const receiveLibError = useMemo<string | null>(() => {
    if (!includeReceiveLib) return null
    const v = receiveLibInput.trim()
    if (!v) return 'receive library address required'
    if (!isAddress(v)) return 'invalid address'
    return null
  }, [includeReceiveLib, receiveLibInput])

  const gracePeriodError = useMemo<string | null>(() => {
    if (!includeReceiveLib) return null
    try {
      const gp = BigInt(gracePeriodInput.trim() || '0')
      if (gp < 0n) return 'must be >= 0'
      return null
    } catch {
      return 'must be a non-negative integer'
    }
  }, [includeReceiveLib, gracePeriodInput])

  const sendUlnParsed = useMemo<UlnParseResult>(
    () => parseUlnFormState(sendUlnForm),
    [sendUlnForm],
  )
  const receiveUlnParsed = useMemo<UlnParseResult>(
    () => parseUlnFormState(receiveUlnForm),
    [receiveUlnForm],
  )

  const sendUlnError = includeSendConfig ? sendUlnParsed.error : null
  const receiveUlnError = includeReceiveConfig ? receiveUlnParsed.error : null

  const executorAddrError = useMemo<string | null>(() => {
    if (!includeSendConfig) return null
    const v = executorAddrInput.trim()
    if (!v) return 'executor address required'
    if (!isAddress(v)) return 'invalid address'
    return null
  }, [includeSendConfig, executorAddrInput])

  const executorSizeError = useMemo<string | null>(() => {
    if (!includeSendConfig) return null
    const n = Number(executorSizeInput.trim() || '0')
    if (!Number.isInteger(n) || n < 0) return 'must be a non-negative integer'
    return null
  }, [includeSendConfig, executorSizeInput])

  // resolution for send/receive lib for setSendConfig / setReceiveConfig
  const resolvedSendLib: Address | null = useMemo(() => {
    if (includeSendLib && sendLibInput && isAddress(sendLibInput.trim())) {
      return sendLibInput.trim() as Address
    }
    return (onChain?.sendLib ?? desired?.sendLib ?? null) as Address | null
  }, [includeSendLib, sendLibInput, onChain, desired])

  const resolvedReceiveLib: Address | null = useMemo(() => {
    if (includeReceiveLib && receiveLibInput && isAddress(receiveLibInput.trim())) {
      return receiveLibInput.trim() as Address
    }
    return (onChain?.receiveLib ?? desired?.receiveLib ?? null) as Address | null
  }, [includeReceiveLib, receiveLibInput, onChain, desired])

  const sendConfigLibMissing =
    includeSendConfig && !resolvedSendLib
      ? 'cannot determine send library — enable "Set send library" or wait for on-chain state'
      : null
  const receiveConfigLibMissing =
    includeReceiveConfig && !resolvedReceiveLib
      ? 'cannot determine receive library — enable "Set receive library" or wait for on-chain state'
      : null

  const anyIncluded =
    includePeer || includeSendLib || includeReceiveLib || includeSendConfig || includeReceiveConfig

  const hasAnyError = Boolean(
    peerError ||
      sendLibError ||
      receiveLibError ||
      gracePeriodError ||
      sendUlnError ||
      receiveUlnError ||
      executorAddrError ||
      executorSizeError ||
      sendConfigLibMissing ||
      receiveConfigLibMissing,
  )

  const submitDisabled =
    !anyIncluded || hasAnyError || !eid || !oAppAddress

  function handleSubmit() {
    setSubmitError(null)
    if (!eid || !oAppAddress) {
      setSubmitError('Missing remote EID or OApp address; cannot build edits.')
      return
    }
    const edits: PendingEdit[] = []

    if (includePeer && !peerError) {
      edits.push({
        kind: 'setPeer',
        sourceChain,
        oApp,
        oAppAddress,
        remoteChain,
        eid,
        peerBytes32: addressToBytes32(peerInput.trim() as Address),
      })
    }

    if (includeSendLib && !sendLibError) {
      edits.push({
        kind: 'setSendLibrary',
        sourceChain,
        oApp,
        oAppAddress,
        remoteChain,
        eid,
        lib: sendLibInput.trim() as Address,
      })
    }

    if (includeReceiveLib && !receiveLibError && !gracePeriodError) {
      edits.push({
        kind: 'setReceiveLibrary',
        sourceChain,
        oApp,
        oAppAddress,
        remoteChain,
        eid,
        lib: receiveLibInput.trim() as Address,
        gracePeriod: BigInt(gracePeriodInput.trim() || '0'),
      })
    }

    if (includeSendConfig && !sendUlnError && !executorAddrError && !executorSizeError) {
      if (!resolvedSendLib) {
        setSubmitError(
          'Cannot include Set send config without a send library. Either enable "Set send library" with a valid address or wait for on-chain state to load.',
        )
        return
      }
      const executor: ExecutorConfig = {
        executorAddress: executorAddrInput.trim() as Address,
        maxMessageSize: Number(executorSizeInput.trim() || '0'),
      }
      edits.push({
        kind: 'setSendConfig',
        sourceChain,
        oApp,
        oAppAddress,
        remoteChain,
        eid,
        sendLib: resolvedSendLib,
        executor,
        uln: sendUlnParsed.uln!,
      })
    }

    if (includeReceiveConfig && !receiveUlnError) {
      if (!resolvedReceiveLib) {
        setSubmitError(
          'Cannot include Set receive config without a receive library. Either enable "Set receive library" with a valid address or wait for on-chain state to load.',
        )
        return
      }
      edits.push({
        kind: 'setReceiveConfig',
        sourceChain,
        oApp,
        oAppAddress,
        remoteChain,
        eid,
        receiveLib: resolvedReceiveLib,
        uln: receiveUlnParsed.uln!,
      })
    }

    if (edits.length === 0) {
      setSubmitError('No edits selected.')
      return
    }
    onSubmit(edits)
  }

  return (
    <div className="fixed inset-0 z-40">
      <div
        className="absolute inset-0 bg-black/60"
        onClick={onClose}
        aria-label="Close drawer"
        role="button"
        tabIndex={-1}
      />
      <aside
        className="absolute top-0 right-0 h-full w-full md:w-[640px] bg-charcoal-900 border-l border-white/10 overflow-y-auto"
        style={{ backgroundColor: 'rgb(15 23 42)' }}
      >
        <header className="sticky top-0 bg-charcoal-900 border-b border-white/10 px-5 py-4 flex items-center justify-between gap-4 z-10">
          <div>
            <div className="text-xs uppercase tracking-wider text-slate-500">
              Edit route
            </div>
            <h3 className="text-base font-semibold text-white">
              {oApp} · {sourceChain} → <span className="capitalize">{remoteChain}</span>
              {eid ? <span className="text-slate-500 ml-2 text-xs">eid {eid}</span> : null}
            </h3>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="text-slate-400 hover:text-white text-2xl leading-none px-2"
            aria-label="Close"
          >
            ×
          </button>
        </header>

        <div className="px-5 py-4">
          {isLoading ? (
            <div className="text-xs text-slate-400 mb-3">Loading on-chain state…</div>
          ) : null}

          {!desired ? (
            <div className="text-amber-300 text-xs mb-3 bg-amber-500/10 border border-amber-500/20 rounded-lg px-3 py-2">
              No desired config in <code>config/index.json</code> for this route. Defaults are
              empty — please fill the fields manually.
            </div>
          ) : null}

          <SectionToggle
            title="Set peer"
            included={includePeer}
            onToggle={setIncludePeer}
          >
            <Field label="Peer address (remote OApp)" error={peerError}>
              <input
                type="text"
                value={peerInput}
                onChange={(e) => setPeerInput(e.target.value)}
                placeholder="0x…"
                className={inputCls}
              />
            </Field>
          </SectionToggle>

          <SectionToggle
            title="Set send library"
            included={includeSendLib}
            onToggle={setIncludeSendLib}
          >
            <Field label="Send library address" error={sendLibError}>
              <input
                type="text"
                value={sendLibInput}
                onChange={(e) => setSendLibInput(e.target.value)}
                placeholder="0x…"
                className={inputCls}
              />
            </Field>
          </SectionToggle>

          <SectionToggle
            title="Set receive library"
            included={includeReceiveLib}
            onToggle={setIncludeReceiveLib}
          >
            <Field label="Receive library address" error={receiveLibError}>
              <input
                type="text"
                value={receiveLibInput}
                onChange={(e) => setReceiveLibInput(e.target.value)}
                placeholder="0x…"
                className={inputCls}
              />
            </Field>
            <Field label="Grace period (blocks)" error={gracePeriodError}>
              <input
                type="number"
                min={0}
                value={gracePeriodInput}
                onChange={(e) => setGracePeriodInput(e.target.value)}
                className={inputCls}
              />
            </Field>
          </SectionToggle>

          <SectionToggle
            title="Set send config (ULN + Executor)"
            included={includeSendConfig}
            onToggle={setIncludeSendConfig}
          >
            {sendConfigLibMissing ? (
              <div className="text-red-400 text-xs mb-3">{sendConfigLibMissing}</div>
            ) : (
              <div className="text-xs text-slate-500 mb-3">
                Send library:{' '}
                <span className="font-mono text-slate-300">{resolvedSendLib ?? '—'}</span>
              </div>
            )}
            <Field label="Executor address" error={executorAddrError}>
              <input
                type="text"
                value={executorAddrInput}
                onChange={(e) => setExecutorAddrInput(e.target.value)}
                placeholder="0x…"
                className={inputCls}
              />
            </Field>
            <Field label="Executor maxMessageSize" error={executorSizeError}>
              <input
                type="number"
                min={0}
                value={executorSizeInput}
                onChange={(e) => setExecutorSizeInput(e.target.value)}
                className={inputCls}
              />
            </Field>
            <UlnFormFields
              form={sendUlnForm}
              onChange={setSendUlnForm}
              error={sendUlnError}
              idPrefix="send"
            />
          </SectionToggle>

          <SectionToggle
            title="Set receive config (ULN)"
            included={includeReceiveConfig}
            onToggle={setIncludeReceiveConfig}
          >
            {receiveConfigLibMissing ? (
              <div className="text-red-400 text-xs mb-3">{receiveConfigLibMissing}</div>
            ) : (
              <div className="text-xs text-slate-500 mb-3">
                Receive library:{' '}
                <span className="font-mono text-slate-300">{resolvedReceiveLib ?? '—'}</span>
              </div>
            )}
            <UlnFormFields
              form={receiveUlnForm}
              onChange={setReceiveUlnForm}
              error={receiveUlnError}
              idPrefix="receive"
            />
          </SectionToggle>

          {submitError ? (
            <div className="text-red-400 text-xs mb-3 bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2">
              {submitError}
            </div>
          ) : null}
        </div>

        <footer className="sticky bottom-0 bg-charcoal-900 border-t border-white/10 px-5 py-4 flex items-center justify-end gap-3">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-sm rounded-lg text-slate-300 hover:text-white hover:bg-white/5 transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleSubmit}
            disabled={submitDisabled}
            className={`px-4 py-2 text-sm rounded-lg transition-colors ${
              submitDisabled
                ? 'bg-white/5 text-slate-500 cursor-not-allowed'
                : 'bg-primary/20 text-primary hover:bg-primary/30'
            }`}
          >
            Add to pending changes
          </button>
        </footer>
      </aside>
    </div>
  )
}

function UlnFormFields({
  form,
  onChange,
  error,
  idPrefix,
}: {
  form: UlnFormState
  onChange: (next: UlnFormState) => void
  error: string | null
  idPrefix: string
}) {
  function update<K extends keyof UlnFormState>(key: K, value: UlnFormState[K]) {
    onChange({ ...form, [key]: value })
  }
  return (
    <div>
      <h5 className="text-xs uppercase tracking-wider text-slate-500 mb-2">ULN config</h5>
      <div className="grid grid-cols-2 gap-3 mb-1">
        <Field label="confirmations">
          <input
            id={`${idPrefix}-confirmations`}
            type="number"
            min={0}
            value={form.confirmations}
            onChange={(e) => update('confirmations', e.target.value)}
            className={inputCls}
          />
        </Field>
        <Field label="requiredDVNCount">
          <input
            id={`${idPrefix}-requiredDVNCount`}
            type="number"
            min={0}
            value={form.requiredDVNCount}
            onChange={(e) => update('requiredDVNCount', e.target.value)}
            className={inputCls}
          />
        </Field>
        <Field label="optionalDVNCount">
          <input
            id={`${idPrefix}-optionalDVNCount`}
            type="number"
            min={0}
            value={form.optionalDVNCount}
            onChange={(e) => update('optionalDVNCount', e.target.value)}
            className={inputCls}
          />
        </Field>
        <Field label="optionalDVNThreshold">
          <input
            id={`${idPrefix}-optionalDVNThreshold`}
            type="number"
            min={0}
            value={form.optionalDVNThreshold}
            onChange={(e) => update('optionalDVNThreshold', e.target.value)}
            className={inputCls}
          />
        </Field>
      </div>
      <Field label="requiredDVNs (one address per line)">
        <textarea
          id={`${idPrefix}-requiredDVNs`}
          value={form.requiredDVNs}
          onChange={(e) => update('requiredDVNs', e.target.value)}
          rows={3}
          className={`${inputCls} font-mono`}
          placeholder="0x…"
        />
      </Field>
      <Field label="optionalDVNs (one address per line)">
        <textarea
          id={`${idPrefix}-optionalDVNs`}
          value={form.optionalDVNs}
          onChange={(e) => update('optionalDVNs', e.target.value)}
          rows={3}
          className={`${inputCls} font-mono`}
          placeholder="0x…"
        />
      </Field>
      {error ? <div className="text-red-400 text-xs mt-1">{error}</div> : null}
    </div>
  )
}
