import React from 'react'

export type ProposalStatus =
  | 'Pending'
  | 'Active'
  | 'Succeeded'
  | 'Queued'
  | 'Ready'
  | 'Executed'
  | 'Executed on Hub'
  | 'Defeated'
  | 'Canceled'

interface ProposalFilterProps {
  selectedStatuses: ProposalStatus[]
  onStatusChange: (statuses: ProposalStatus[]) => void
}

export const ProposalFilter: React.FC<ProposalFilterProps> = ({
  selectedStatuses,
  onStatusChange,
}) => {
  const allStatuses: ProposalStatus[] = [
    'Pending',
    'Active',
    'Succeeded',
    'Queued',
    'Ready',
    'Executed',
    'Executed on Hub',
    'Defeated',
    'Canceled',
  ]

  const handleStatusChange = (status: ProposalStatus) => {
    if (selectedStatuses.includes(status)) {
      onStatusChange(selectedStatuses.filter((s) => s !== status))
    } else {
      onStatusChange([...selectedStatuses, status])
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      <span className="text-[11px] font-semibold tracking-wider text-fg3 uppercase">
        Filter status
      </span>
      <div className="flex flex-wrap items-center gap-1.5">
        {allStatuses.map((status) => {
          const isSelected = selectedStatuses.includes(status)
          return (
            <button
              key={status}
              onClick={() => handleStatusChange(status)}
              className={`h-7 px-3 rounded-full text-xs font-medium border transition-colors cursor-pointer ${
                isSelected
                  ? 'border-brand-pink bg-pink-bg text-brand-pink'
                  : 'border-line2 bg-surface3 text-fg2 hover:text-fg hover:bg-surface2'
              }`}
            >
              {status}
            </button>
          )
        })}
      </div>
    </div>
  )
}
