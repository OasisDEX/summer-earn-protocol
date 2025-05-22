'use client'

import { CrossChainProposals } from '../../components/CrossChainProposals'

export default function CrossChainProposalsPage() {
  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">Cross-Chain Governance Proposals</h1>
      <CrossChainProposals />
    </main>
  )
}
