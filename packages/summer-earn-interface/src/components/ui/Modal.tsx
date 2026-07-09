'use client'

import { type ReactNode } from 'react'

type ModalSize = 'sm' | 'md' | 'lg' | 'xl'

interface ModalProps {
  onClose: () => void
  title: ReactNode
  children: ReactNode
  footer?: ReactNode
  size?: ModalSize
  /** Off by default — enable only where the pre-existing overlay closed on backdrop click. */
  closeOnBackdrop?: boolean
}

const SIZES: Record<ModalSize, string> = {
  sm: 'max-w-sm',
  md: 'max-w-md',
  lg: 'max-w-lg',
  xl: 'max-w-2xl',
}

/**
 * Shared modal chrome. Deliberately has NO `isOpen` prop: callers keep their
 * existing `if (!isOpen) return null` so hook-mount timing never changes.
 */
export function Modal({
  onClose,
  title,
  children,
  footer,
  size = 'md',
  closeOnBackdrop = false,
}: ModalProps) {
  return (
    <div
      className="fixed inset-0 z-modal bg-black/60 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={closeOnBackdrop ? onClose : undefined}
    >
      <div
        className={`w-full ${SIZES[size]} max-h-[85vh] overflow-y-auto scrollbar-thin bg-surface-container-high border border-white/10 rounded-2xl shadow-card`}
        onClick={closeOnBackdrop ? (e) => e.stopPropagation() : undefined}
      >
        <div className="flex items-center justify-between gap-4 px-6 pt-5 pb-4 border-b border-white/5">
          <h2 className="text-lg font-headline font-semibold text-on-surface">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="shrink-0 rounded-lg p-1.5 text-on-surface-variant hover:text-on-surface hover:bg-white/5 transition-colors"
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
              <path
                d="M4 4l8 8M12 4l-8 8"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
              />
            </svg>
          </button>
        </div>
        <div className="px-6 py-5">{children}</div>
        {footer && <div className="px-6 pb-5 pt-1">{footer}</div>}
      </div>
    </div>
  )
}
