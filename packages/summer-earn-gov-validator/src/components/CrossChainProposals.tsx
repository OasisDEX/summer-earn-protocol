import React, { useEffect, useState } from 'react'
import { ProposalWithCrossChain, fetchAllProposals } from '../services/subgraph'

export const CrossChainProposals: React.FC = () => {
  const [proposals, setProposals] = useState<ProposalWithCrossChain[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const loadProposals = async () => {
      try {
        const data = await fetchAllProposals()
        setProposals(data)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load proposals')
      } finally {
        setLoading(false)
      }
    }

    loadProposals()
  }, [])

  if (loading)
    return (
      <div className="flex justify-center items-center min-h-[200px]">
        <div className="animate-pulse flex flex-col items-center space-y-4">
          <div className="h-8 w-32 bg-gray-200 rounded"></div>
          <div className="h-4 w-24 bg-gray-200 rounded"></div>
        </div>
      </div>
    )
  if (error)
    return (
      <div className="text-red-500 p-6 border border-red-200 rounded-lg bg-red-50">
        <div className="flex items-center space-x-2">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <span>Error: {error}</span>
        </div>
      </div>
    )

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
          Cross-Chain Proposals
        </h2>
        <div className="text-sm text-gray-500">Total Proposals: {proposals.length}</div>
      </div>
      <div className="grid gap-6">
        {proposals.map(({ baseProposal, crossChainProposals }) => (
          <div
            key={baseProposal.id}
            className="group border border-gray-200 rounded-xl p-6 space-y-4 bg-white shadow-sm hover:shadow-lg transition-all duration-300 ease-in-out"
          >
            <div className="space-y-4">
              <div className="flex justify-between items-start">
                <div className="space-y-1">
                  <h3 className="text-xl font-semibold text-gray-900">
                    Proposal #{baseProposal.id}
                  </h3>
                  <p className="text-sm text-gray-500">
                    Created on {new Date(Number(baseProposal.eta) * 1000).toLocaleDateString()}
                  </p>
                </div>
                <span
                  className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors duration-200 ${
                    baseProposal.status === 'EXECUTED'
                      ? 'bg-green-100 text-green-800'
                      : baseProposal.status === 'QUEUED'
                        ? 'bg-yellow-100 text-yellow-800'
                        : baseProposal.status === 'ACTIVE'
                          ? 'bg-blue-100 text-blue-800'
                          : 'bg-gray-100 text-gray-800'
                  }`}
                >
                  {baseProposal.status}
                </span>
              </div>
              <p className="text-gray-600 text-sm leading-relaxed bg-gray-50 p-4 rounded-lg">
                {baseProposal.description.slice(0, 100)}
                {baseProposal.description.length > 100 && '...'}
              </p>
              <div className="flex flex-wrap gap-3 text-sm">
                <span className="px-4 py-2 bg-gray-50 rounded-full flex items-center space-x-2">
                  <svg
                    className="w-4 h-4 text-gray-500"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  <span>
                    ETA:{' '}
                    {baseProposal.eta === '0'
                      ? 'Not queued'
                      : new Date(Number(baseProposal.eta) * 1000).toLocaleString()}
                  </span>
                </span>
                <span className="px-4 py-2 bg-gray-50 rounded-full flex items-center space-x-2">
                  <svg
                    className="w-4 h-4 text-gray-500"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M13 10V3L4 14h7v7l9-11h-7z"
                    />
                  </svg>
                  <span>Chains: {baseProposal.chains.join(', ')}</span>
                </span>
              </div>
            </div>

            <div className="space-y-3 pt-4 border-t border-gray-100">
              <div className="flex items-center justify-between">
                <h4 className="text-lg font-medium text-gray-700">Cross-Chain Proposals</h4>
                <span className="text-sm text-gray-500">
                  {crossChainProposals.length} proposals
                </span>
              </div>
              {crossChainProposals.length === 0 ? (
                <p className="text-gray-500 italic bg-gray-50 p-4 rounded-lg text-center">
                  No cross-chain proposals found
                </p>
              ) : (
                <div className="grid gap-3">
                  {crossChainProposals.map((ccp) => (
                    <div
                      key={ccp.id}
                      className="border-l-4 border-blue-500 pl-4 py-3 bg-blue-50 rounded-r-lg hover:bg-blue-100 transition-colors duration-200"
                    >
                      <div className="flex flex-wrap gap-3 items-center">
                        <span className="font-medium text-blue-900 flex items-center space-x-2">
                          <svg
                            className="w-4 h-4"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={2}
                              d="M13 10V3L4 14h7v7l9-11h-7z"
                            />
                          </svg>
                          <span>Chain: {ccp.chainId}</span>
                        </span>
                        <span
                          className={`px-3 py-1 rounded-full text-sm ${
                            ccp.status === 'EXECUTED'
                              ? 'bg-green-100 text-green-800'
                              : ccp.status === 'QUEUED'
                                ? 'bg-yellow-100 text-yellow-800'
                                : ccp.status === 'ACTIVE'
                                  ? 'bg-blue-100 text-blue-800'
                                  : 'bg-gray-100 text-gray-800'
                          }`}
                        >
                          {ccp.status}
                        </span>
                      </div>
                      <p className="text-sm text-blue-700 mt-2 font-mono">ID: {ccp.id}</p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
