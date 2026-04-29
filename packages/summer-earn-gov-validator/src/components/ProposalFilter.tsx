import React from 'react'

export type ProposalStatus = 'Pending' | 'Executed' | 'Active' | 'Succeeded' | 'Queued' | 'Ready'

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
  ]

  const handleStatusChange = (status: ProposalStatus) => {
    if (selectedStatuses.includes(status)) {
      onStatusChange(selectedStatuses.filter((s) => s !== status))
    } else {
      onStatusChange([...selectedStatuses, status])
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-4">
      <span className="text-[10px] font-black text-on-surface-variant uppercase tracking-[0.2em] ml-1">
        Filter status
      </span>
      <div className="bg-surface-container-low/50 border border-outline-variant/10 p-1 rounded-xl flex flex-wrap items-center gap-1 shadow-inner">
        {allStatuses.map((status) => (
          <button
            key={status}
            onClick={() => handleStatusChange(status)}
            className={`px-4 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all duration-200 active:scale-95 ${
              selectedStatuses.includes(status)
                ? 'bg-brand-gradient text-black shadow-neon-strong'
                : 'text-on-surface-variant hover:text-on-surface hover:bg-surface-bright/50'
            }`}
          >
            {status}
          </button>
        ))}
      </div>
    </div>
  )
}
