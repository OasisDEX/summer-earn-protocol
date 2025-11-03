import React from 'react'
import ReactMarkdown from 'react-markdown'

import { calculateProposalTiming } from '@/utils/timing'

import { PhaseIndicator } from './PhaseIndicator'

interface Proposal {
  id: string
  targets: string[]
  values: string[]
  calldatas: string[]
  description: string
  descriptionHash: string
  status: string
  chains: string[]
  createdAt?: string
}

interface ProposalModalProps {
  proposal: Proposal | null
  contractNames: string[]
  isOpen: boolean
  onClose: () => void
}

export const ProposalModal: React.FC<ProposalModalProps> = ({
  proposal,
  contractNames,
  isOpen,
  onClose,
}) => {
  if (!isOpen || !proposal) return null

  const timing = proposal.createdAt
    ? calculateProposalTiming({
        status: proposal.status,
        createdAt: proposal.createdAt,
      })
    : null

  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose()
    }
  }

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 dark:bg-opacity-70 flex items-center justify-center z-50 p-4 animate-fade-in"
      onClick={handleBackdropClick}
      onKeyDown={handleKeyDown}
      tabIndex={-1}
    >
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col animate-slide-in">
        <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900">
          <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
            Proposal #{proposal.id}
          </h2>
          <button
            className="p-2 rounded-lg text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors duration-200"
            onClick={onClose}
            aria-label="Close modal"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6">
          {timing && (
            <div className="mb-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
              <PhaseIndicator timing={timing} variant="detailed" />
            </div>
          )}

          <div className="mb-6">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
              Description
            </h3>
            <div className="prose dark:prose-invert max-w-none">
              <ReactMarkdown>{proposal.description}</ReactMarkdown>
            </div>
          </div>

          <div className="mb-6">
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
              Targets & Values
            </h3>
            <div className="space-y-3">
              {proposal.targets.map((target, index) => (
                <div
                  key={index}
                  className="p-4 bg-gray-50 dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600"
                >
                  <div className="flex justify-between items-center mb-2">
                    <span className="text-sm font-medium text-gray-600 dark:text-gray-300">
                      Target {index + 1}:
                    </span>
                    <span className="text-sm font-semibold text-green-600 dark:text-green-400">
                      {proposal.values[index]} ETH
                    </span>
                  </div>
                  <div className="space-y-1">
                    <div className="font-mono text-sm text-blue-600 dark:text-blue-400 break-all">
                      {target}
                    </div>
                    <div className="text-sm text-gray-500 dark:text-gray-400 italic">
                      ({contractNames[index]})
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {proposal.chains && proposal.chains.length > 0 && (
            <div className="mb-6">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
                Affected Chains
              </h3>
              <div className="flex flex-wrap gap-2">
                {proposal.chains.map((chain) => (
                  <span
                    key={chain}
                    className="px-3 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 rounded-full text-sm font-medium"
                  >
                    {chain.charAt(0).toUpperCase() + chain.slice(1)}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>

        <div className="p-6 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 flex justify-end">
          <button
            className="px-4 py-2 bg-gray-600 dark:bg-gray-700 text-white rounded-lg hover:bg-gray-700 dark:hover:bg-gray-600 transition-colors duration-200 font-medium"
            onClick={onClose}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
