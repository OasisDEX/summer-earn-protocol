'use client'

import { Pill } from '@/components/ui/Pill'
import { formatDecimalOutput, formatUnixDate, shortAddress } from '@/lib/format'
import type { SubgraphExecution } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'
import { txExplorerUrl } from '@/utils/explorer'

interface ExecutionHistoryTableProps {
  executions: SubgraphExecution[]
  chainId: ChainId
  inDecimals: number
  outDecimals: number
  inSymbol: string
  outSymbol: string
}

export function ExecutionHistoryTable({
  executions,
  chainId,
  inDecimals,
  outDecimals,
  inSymbol,
  outSymbol,
}: ExecutionHistoryTableProps) {
  if (executions.length === 0) {
    return <p className="text-sm text-[var(--text-3)]">No executions yet.</p>
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm" style={{ borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <Th>Date</Th>
            <Th>Status</Th>
            <Th>Spent</Th>
            <Th>Received</Th>
            <Th>Price</Th>
            <Th>Tx</Th>
          </tr>
        </thead>
        <tbody>
          {executions.map((ex) => {
            const inAmt = BigInt(ex.inAssets)
            const outAmt = BigInt(ex.outAssets)
            const skipped = outAmt === 0n
            const priceLabel = skipped
              ? '—'
              : `${formatDecimalOutput(inAmt, inDecimals, 4)} / ${formatDecimalOutput(outAmt, outDecimals, 6)}`
            return (
              <tr
                key={ex.id}
                className="cursor-default border-b border-[var(--border-faint)] last:border-b-0 transition hover:bg-[var(--surface-hover)]"
              >
                <Td>{formatUnixDate(BigInt(ex.executionTimestamp))}</Td>
                <Td>
                  {skipped ? (
                    <Pill variant="cancelled">Skipped</Pill>
                  ) : (
                    <Pill variant="active">Executed</Pill>
                  )}
                </Td>
                <Td className="font-mono">
                  {formatDecimalOutput(inAmt, inDecimals, 2)} {inSymbol}
                </Td>
                <Td className="font-mono">
                  {formatDecimalOutput(outAmt, outDecimals, 6)} {outSymbol}
                </Td>
                <Td className="font-mono">{priceLabel}</Td>
                <Td>
                  <a
                    href={txExplorerUrl(chainId, ex.txHash)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="font-mono text-[var(--text-2)] transition hover:text-[var(--text)]"
                  >
                    {shortAddress(ex.txHash)} ↗
                  </a>
                </Td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

function Th({ children }: { children: React.ReactNode }) {
  return (
    <th className="border-b border-[var(--border-faint)] px-[var(--row-px)] py-3 text-left text-[11px] font-medium uppercase tracking-[0.06em] text-[var(--text-3)]">
      {children}
    </th>
  )
}

function Td({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return (
    <td
      className={[
        'border-b border-[var(--border-faint)] px-[var(--row-px)] py-[var(--row-py)] align-middle text-[var(--text)]',
        className,
      ].join(' ')}
    >
      {children}
    </td>
  )
}
