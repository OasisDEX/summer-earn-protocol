import { encodeFunctionData, Hex } from 'viem'

import { AbiItem, ProposalAction } from '@/types/governance'

export type GasSeverity = 'ok' | 'warning' | 'critical'
export type GasSeverityOrIdle = GasSeverity | 'idle'

export const GAS_SEVERITY_ORDER: Record<GasSeverityOrIdle, number> = {
  idle: 0,
  ok: 1,
  warning: 2,
  critical: 3,
}

export const DEFAULT_LZ_GAS_LIMIT = '500000'
export const LZ_GAS_WARNING_THRESHOLD = 0.7
export const LZ_GAS_CRITICAL_THRESHOLD = 1.0
export const LZ_GAS_HEADROOM_PERCENT = Math.round((1 - LZ_GAS_WARNING_THRESHOLD) * 100)

export const ZERO_BYTES32 =
  '0x0000000000000000000000000000000000000000000000000000000000000000' as Hex

export const bigIntSafeReplacer = (_key: string, value: unknown): unknown =>
  typeof value === 'bigint' ? value.toString() : value

export const parseLzGas = (raw: string | undefined): bigint => {
  if (!raw) return BigInt(DEFAULT_LZ_GAS_LIMIT)
  const cleaned = raw.replace(/[_,\s]/g, '')
  // After stripping separators we require ≥1 decimal digit; BigInt() cannot
  // throw on a non-empty decimal string, so no try/catch is needed here.
  if (!/^\d+$/.test(cleaned)) return BigInt(DEFAULT_LZ_GAS_LIMIT)
  return BigInt(cleaned)
}

// Single source of truth for per-action calldata. Used by encodeProposal AND
// by the simulation builder so the bytes Tenderly executes are byte-identical
// to the bytes the proposal will eventually execute. When `inputs` is missing
// on a malformed ABI we still emit the function selector — `0x` would silently
// invoke the contract's fallback, which is almost certainly not the intent.
export const buildActionCalldata = (a: ProposalAction): Hex => {
  if (a.rawCalldata) return a.rawCalldata as Hex
  const methodObj = a.abi.find((m: AbiItem) => m.name === a.method)
  if (!methodObj) return '0x' as Hex
  return encodeFunctionData({
    abi: [methodObj],
    functionName: a.method,
    args: methodObj.inputs?.map((i) => a.args[i.name]) ?? [],
  })
}

export const computeGasSeverity = (gasUsed: number, encodedGas: bigint): GasSeverity => {
  const encodedGasNum = Number(encodedGas)
  const ratio = encodedGasNum === 0 ? Number.POSITIVE_INFINITY : gasUsed / encodedGasNum
  if (ratio >= LZ_GAS_CRITICAL_THRESHOLD) return 'critical'
  if (ratio >= LZ_GAS_WARNING_THRESHOLD) return 'warning'
  return 'ok'
}

export const computeGasRatio = (gasUsed: number, encodedGas: bigint): number => {
  const encodedGasNum = Number(encodedGas)
  return encodedGasNum === 0 ? Number.POSITIVE_INFINITY : gasUsed / encodedGasNum
}

export const worstSeverity = (severities: ReadonlyArray<GasSeverityOrIdle>): GasSeverityOrIdle =>
  severities.reduce<GasSeverityOrIdle>(
    (acc, s) => (GAS_SEVERITY_ORDER[s] > GAS_SEVERITY_ORDER[acc] ? s : acc),
    'idle',
  )

// Splits the chains a proposal touches into those Tenderly can simulate and
// those it cannot. Chains without a Tenderly network (e.g. HyperLiquid /
// chainId 999) cannot produce a simulation, so the submit gate must require a
// `success` only for `required` — otherwise an unsimulatable destination would
// permanently disable submit. `unsimulatable` drives the "no Tenderly trace"
// warning. `isSimulatable` is typically derived from CHAINS[*].tenderlyId.
// Order within each partition mirrors the input.
export const partitionSimChains = (
  expectedChainIds: ReadonlyArray<string>,
  isSimulatable: (chainId: string) => boolean,
): { required: string[]; unsimulatable: string[] } => {
  const required: string[] = []
  const unsimulatable: string[] = []
  for (const chainId of expectedChainIds) {
    if (isSimulatable(chainId)) required.push(chainId)
    else unsimulatable.push(chainId)
  }
  return { required, unsimulatable }
}
