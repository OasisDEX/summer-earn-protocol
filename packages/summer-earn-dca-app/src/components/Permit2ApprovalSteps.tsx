'use client'

import { useState } from 'react'
import type { Address } from 'viem'

import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardTitle } from '@/components/ui/Card'
import { CHAIN_NAMES } from '@/config/chains'
import { usePermit2Approval } from '@/hooks/usePermit2Approval'
import type { ChainId } from '@/types/chain'

interface Permit2ApprovalStepsProps {
  chainId: ChainId
  sourceVault: Address | undefined
  requiredShares: bigint | undefined
}

// 3-step flow:
//   1) ERC20 approval of the source vault token to Permit2
//   2) Permit2 approval to DCAStrategyManager (direct tx or EIP-712 signature)
//   3) Ready — the strategy create/resume/edit button unblocks
export function Permit2ApprovalSteps({
  chainId,
  sourceVault,
  requiredShares,
}: Permit2ApprovalStepsProps) {
  const p = usePermit2Approval({ chainId, sourceVault, requiredShares })
  const [useSig, setUseSig] = useState(false)

  return (
    <Card>
      <CardHeader>
        <CardTitle>Permit2 approvals</CardTitle>
        <div className="text-xs text-surface-400">
          The DCA manager pulls vault shares via Permit2 on each execution.
        </div>
      </CardHeader>

      <ol className="space-y-3 text-sm">
        <li
          className={[
            'flex items-start justify-between gap-3 rounded-md border p-3',
            p.step === 'needs-erc20'
              ? 'border-warning/40 bg-warning/10'
              : 'border-surface-700 bg-surface-900/60',
          ].join(' ')}
        >
          <div>
            <div className="font-medium text-surface-100">
              1. Allow Permit2 to spend your shares
            </div>
            <div className="text-xs text-surface-400">Standard ERC20 approve, one-time.</div>
          </div>
          <Button
            variant="secondary"
            disabled={p.step !== 'needs-erc20' || p.isWrongChain}
            loading={p.approveErc20Tx.isWriting || p.approveErc20Tx.isMining}
            onClick={p.approveErc20}
          >
            {p.step === 'needs-erc20' ? 'Approve' : 'Done'}
          </Button>
        </li>

        <li
          className={[
            'rounded-md border p-3',
            p.step === 'needs-permit2'
              ? 'border-warning/40 bg-warning/10'
              : 'border-surface-700 bg-surface-900/60',
          ].join(' ')}
        >
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="font-medium text-surface-100">
                2. Approve the DCA manager via Permit2
              </div>
              <div className="text-xs text-surface-400">
                {useSig
                  ? 'Sign EIP-712 data, then submit Permit2.permit(...).'
                  : 'Direct Permit2.approve() — one tx, no signature.'}
              </div>
            </div>
            <Button
              variant="secondary"
              disabled={p.step !== 'needs-permit2' || p.isWrongChain}
              loading={
                useSig
                  ? p.isSigning || p.approvePermit2SigTx.isWriting || p.approvePermit2SigTx.isMining
                  : p.approvePermit2DirectTx.isWriting || p.approvePermit2DirectTx.isMining
              }
              onClick={useSig ? p.approvePermit2Sig : p.approvePermit2Direct}
            >
              {p.step === 'needs-permit2' ? (useSig ? 'Sign + submit' : 'Approve') : 'Done'}
            </Button>
          </div>
          <label className="mt-2 flex items-center gap-2 text-xs text-surface-400">
            <input
              type="checkbox"
              checked={useSig}
              onChange={(e) => setUseSig(e.target.checked)}
              disabled={p.step !== 'needs-permit2'}
            />
            Use EIP-712 signature flow
          </label>
        </li>
      </ol>

      {p.step === 'ready' && (
        <div className="mt-4 rounded-md border border-success/40 bg-success/10 p-3 text-sm text-success">
          Approvals complete. You can create the strategy.
        </div>
      )}
      {p.isWrongChain && (
        <div className="mt-4 rounded-md border border-warning/40 bg-warning/10 p-3 text-sm text-warning">
          Switch your wallet to {CHAIN_NAMES[chainId]} to approve.
        </div>
      )}
    </Card>
  )
}
