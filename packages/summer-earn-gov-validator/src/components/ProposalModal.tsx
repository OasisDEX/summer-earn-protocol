import { calculateProposalTiming } from '@/utils/timing'
import React from 'react'
import ReactMarkdown from 'react-markdown'
import styles from '../styles/Form.module.scss'
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
      className={styles.modalBackdrop}
      onClick={handleBackdropClick}
      onKeyDown={handleKeyDown}
      tabIndex={-1}
    >
      <div className={styles.modalContent}>
        <div className={styles.modalHeader}>
          <h2 className={styles.modalTitle}>Proposal #{proposal.id}</h2>
          <button className={styles.modalCloseButton} onClick={onClose} aria-label="Close modal">
            <svg className={styles.closeIcon} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        <div className={styles.modalBody}>
          {timing && (
            <div className={styles.modalTimingSection}>
              <PhaseIndicator timing={timing} variant="detailed" />
            </div>
          )}

          <div className={styles.modalDescription}>
            <h3 className={styles.modalSectionTitle}>Description</h3>
            <div className={styles.description}>
              <ReactMarkdown>{proposal.description}</ReactMarkdown>
            </div>
          </div>

          <div className={styles.modalTargets}>
            <h3 className={styles.modalSectionTitle}>Targets & Values</h3>
            <div className={styles.targetsList}>
              {proposal.targets.map((target, index) => (
                <li key={index} className={styles.modalTargetItem}>
                  <div className={styles.modalTargetHeader}>
                    <span className={styles.label}>Target {index + 1}:</span>
                    <span className={styles.value}>{proposal.values[index]} ETH</span>
                  </div>
                  <div className={styles.modalTargetDetails}>
                    <span className={styles.address}>{target}</span>
                    <span className={styles.contractName}>({contractNames[index]})</span>
                  </div>
                </li>
              ))}
            </div>
          </div>

          {proposal.chains && proposal.chains.length > 0 && (
            <div className={styles.modalChains}>
              <h3 className={styles.modalSectionTitle}>Affected Chains</h3>
              <div className={styles.chains}>
                {proposal.chains.map((chain) => (
                  <span key={chain} className={styles.chain}>
                    {chain.charAt(0).toUpperCase() + chain.slice(1)}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>

        <div className={styles.modalFooter}>
          <button className={styles.modalCancelButton} onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
