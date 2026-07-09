'use client'

import { type ReactNode } from 'react'

interface EmptyStateProps {
  icon?: ReactNode
  title: string
  description?: ReactNode
  action?: ReactNode
  className?: string
}

function StateShell({
  icon,
  title,
  description,
  action,
  className = '',
  tone,
}: EmptyStateProps & { tone: 'neutral' | 'error' }) {
  return (
    <div
      className={`relative overflow-hidden rounded-xl border ${
        tone === 'error' ? 'border-error/20 bg-error/[0.04]' : 'border-white/5 bg-white/[0.02]'
      } px-6 py-12 text-center ${className}`}
    >
      {/* horizon-line echo */}
      <div
        aria-hidden="true"
        className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-primary/50 to-transparent"
      />
      {icon && (
        <div className="mb-3 flex justify-center text-2xl text-on-surface-variant">{icon}</div>
      )}
      <h3 className="font-headline font-semibold text-on-surface">{title}</h3>
      {description && (
        <p className="mx-auto mt-1.5 max-w-md text-sm text-on-surface-variant">{description}</p>
      )}
      {action && <div className="mt-4 flex justify-center">{action}</div>}
    </div>
  )
}

export function EmptyState(props: EmptyStateProps) {
  return <StateShell {...props} tone="neutral" />
}

interface ErrorStateProps extends EmptyStateProps {
  error?: { message?: string } | null
}

export function ErrorState({ error, description, ...props }: ErrorStateProps) {
  return <StateShell {...props} description={description ?? error?.message} tone="error" />
}

/** Standard degradation notice for pages whose subgraph data source is being sunset. */
export function RetiredDataNotice({
  what = 'This data source',
  action,
}: {
  what?: string
  action?: ReactNode
}) {
  return (
    <ErrorState
      title="Data unavailable"
      description={`${what} has been retired as part of the protocol sunset. On-chain functionality elsewhere in this app is unaffected.`}
      action={action}
    />
  )
}
