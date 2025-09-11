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
    <div className="flex flex-wrap gap-2 items-center">
      <span className="text-sm font-medium text-gray-700">Filter by status:</span>
      <div className="flex flex-wrap gap-2">
        {allStatuses.map((status) => (
          <button
            key={status}
            onClick={() => handleStatusChange(status)}
            className={`px-3 py-1.5 rounded-full text-sm font-medium transition-colors duration-200 ${
              selectedStatuses.includes(status)
                ? 'bg-blue-100 text-blue-800 border border-blue-300'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200 border border-gray-200'
            }`}
          >
            {status}
          </button>
        ))}
      </div>
    </div>
  )
}
