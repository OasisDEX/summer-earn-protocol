'use client'

import { CrossChainProposals } from '../../components/CrossChainProposals'
import { DashboardLayout } from '../../components/DashboardLayout'

export default function CrossChainProposalsPage() {
  return (
    <DashboardLayout>
      <div className="mb-[18px]">
        <h1 className="m-0 text-[26px] font-semibold tracking-[-0.03em] text-fg">
          Cross-Chain Proposals
        </h1>
        <p className="mt-1 text-fg2 text-xs">
          Hub proposals on Base and their satellite execute-only legs.
        </p>
      </div>
      <CrossChainProposals />
    </DashboardLayout>
  )
}
