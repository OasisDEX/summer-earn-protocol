'use client'

import { type ReactNode, useEffect } from 'react'
import { createPortal } from 'react-dom'

interface DrawerProps {
  open: boolean
  onClose: () => void
  title?: ReactNode
  footer?: ReactNode
  children: ReactNode
  width?: number
}

export function Drawer({ open, onClose, title, footer, children, width = 460 }: DrawerProps) {
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
    <>
      <div
        role="presentation"
        onClick={onClose}
        style={{ animation: 'scrim-in .18s ease' }}
        className="fixed inset-0 z-[100] bg-[rgba(4,4,8,0.65)] backdrop-blur-[6px]"
      />
      <aside
        role="dialog"
        aria-modal="true"
        style={{
          width,
          animation: 'drawer-in .25s cubic-bezier(.2,.8,.2,1)',
          boxShadow: '-20px 0 60px -20px rgba(0,0,0,.6)',
        }}
        className="fixed inset-y-0 right-0 z-[101] flex max-w-full flex-col border-l border-[var(--border)] bg-[var(--bg-elev)]"
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
        <div className="flex-1 overflow-y-auto p-6">{children}</div>
        {footer && (
          <div className="flex gap-2.5 border-t border-[var(--border-faint)] px-6 py-4">
            {footer}
          </div>
        )}
      </aside>
    </>,
    document.body,
  )
}
