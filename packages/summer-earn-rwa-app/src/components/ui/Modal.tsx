'use client'

import { type ReactNode, useEffect } from 'react'
import { createPortal } from 'react-dom'

interface ModalProps {
  open: boolean
  onClose: () => void
  title?: ReactNode
  footer?: ReactNode
  children: ReactNode
  maxWidth?: number
}

export function Modal({ open, onClose, title, footer, children, maxWidth = 540 }: ModalProps) {
  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handler)
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', handler)
      document.body.style.overflow = prev
    }
  }, [open, onClose])

  if (!open || typeof window === 'undefined') return null

  return createPortal(
    <div
      role="presentation"
      onClick={onClose}
      style={{ animation: 'scrim-in .18s ease' }}
      className="fixed inset-0 z-[100] grid place-items-center bg-[rgba(4,4,8,0.7)] p-6 backdrop-blur-[8px]"
    >
      <div
        role="dialog"
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
        style={{ maxWidth, animation: 'modal-in .22s cubic-bezier(.2,.8,.2,1)' }}
        className="w-full rounded-xl border border-[var(--border)] bg-[var(--bg-elev)] shadow-pop"
      >
        {title && (
          <div className="flex items-center justify-between border-b border-[var(--border-faint)] px-6 py-5">
            <div className="h2">{title}</div>
            <button
              type="button"
              aria-label="Close"
              onClick={onClose}
              className="text-[var(--text-3)] transition hover:text-[var(--text)]"
            >
              ✕
            </button>
          </div>
        )}
        <div className="p-6">{children}</div>
        {footer && (
          <div className="flex justify-end gap-2.5 border-t border-[var(--border-faint)] px-6 py-4">
            {footer}
          </div>
        )}
      </div>
    </div>,
    document.body,
  )
}
