'use client'

import { ALL_CHAINS, ALL_OAPPS, type ChainName, type OAppKind } from '../lib/types'

const CHAIN_LABEL: Record<ChainName, string> = {
  mainnet: 'Ethereum',
  arbitrum: 'Arbitrum',
  base: 'Base',
  sonic: 'Sonic',
  hyperliquid: 'Hyperliquid',
}

const OAPP_LABEL: Record<OAppKind, string> = {
  SummerToken: 'SummerToken',
  SummerGovernorV1: 'Governor V1',
  SummerGovernorV2: 'Governor V2',
}

interface Props {
  sourceChain: ChainName
  onChainChange: (c: ChainName) => void
  oApp: OAppKind
  onOAppChange: (o: OAppKind) => void
}

function Pill({ active, label, onClick }: { active: boolean; label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
        active
          ? 'bg-white/10 text-white shadow-xl'
          : 'text-slate-400 hover:text-white hover:bg-white/5'
      }`}
    >
      {label}
    </button>
  )
}

export function ChainAndOAppPicker({ sourceChain, onChainChange, oApp, onOAppChange }: Props) {
  return (
    <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
      <div>
        <div className="text-xs uppercase tracking-wider text-slate-500 mb-2">Source chain</div>
        <div className="inline-flex items-center bg-white/5 border border-white/10 p-1.5 rounded-xl">
          {ALL_CHAINS.map((c) => (
            <Pill
              key={c}
              active={c === sourceChain}
              label={CHAIN_LABEL[c]}
              onClick={() => onChainChange(c)}
            />
          ))}
        </div>
      </div>
      <div>
        <div className="text-xs uppercase tracking-wider text-slate-500 mb-2">OApp</div>
        <div className="inline-flex items-center bg-white/5 border border-white/10 p-1.5 rounded-xl">
          {ALL_OAPPS.map((o) => (
            <Pill
              key={o}
              active={o === oApp}
              label={OAPP_LABEL[o]}
              onClick={() => onOAppChange(o)}
            />
          ))}
        </div>
      </div>
    </div>
  )
}
