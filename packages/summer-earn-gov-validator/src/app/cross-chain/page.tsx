'use client'

import { CrossChainProposals } from '../../components/CrossChainProposals'
import { Header } from '../../components/Header'

export default function CrossChainProposalsPage() {
  return (
    <>
      <Header />
      <main className="container mx-auto px-4 py-8 bg-gray-50 dark:bg-gray-900 min-h-screen">
        <h1 className="text-3xl font-bold mb-8 text-gray-900 dark:text-white">
          Cross-Chain Governance Proposals
        </h1>
        <CrossChainProposals />
      </main>
    </>
  )
}
