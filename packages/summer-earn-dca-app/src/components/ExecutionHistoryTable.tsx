'use client'

import { formatDecimalOutput, formatUnixDate, shortAddress } from '@/lib/format'
import type { SubgraphExecution } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'
import { txExplorerUrl } from '@/utils/explorer'

export function ExecutionHistoryTable({
  executions,
  chainId,
  inDecimals,
  outDecimals,
  inSymbol,
  outSymbol,
}: {
  executions: SubgraphExecution[]
  chainId: ChainId
  inDecimals: number
  outDecimals: number
  inSymbol: string
  outSymbol: string
}) {
  if (executions.length === 0) {
    return <p className="text-sm text-surface-400">No executions yet.</p>
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-surface-700 text-left text-xs uppercase tracking-wide text-surface-500">
            <th className="py-2 pr-3">When</th>
            <th className="py-2 pr-3">In</th>
            <th className="py-2 pr-3">Out</th>
            <th className="py-2 pr-3">Trade #</th>
            <th className="py-2 pr-3">Tx</th>
          </tr>
        </thead>
        <tbody>
          {executions.map((ex) => (
            <tr key={ex.id} className="border-b border-surface-800/80 text-surface-100">
              <td className="py-2 pr-3">{formatUnixDate(BigInt(ex.executionTimestamp))}</td>
              <td className="py-2 pr-3">
                {formatDecimalOutput(BigInt(ex.amountIn), inDecimals)} {inSymbol}
              </td>
              <td className="py-2 pr-3">
                {formatDecimalOutput(BigInt(ex.amountOut), outDecimals)} {outSymbol}
              </td>
              <td className="py-2 pr-3">{ex.tradesExecutedAfter}</td>
              <td className="py-2 pr-3">
                <a
                  href={txExplorerUrl(chainId, ex.txHash)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-primary hover:underline"
                >
                  {shortAddress(ex.txHash)}
                </a>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
