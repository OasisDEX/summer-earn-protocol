import { useState } from 'react'

import { ProposalList } from './ProposalList'

interface Proposal {
  id: string
  targets: string[]
  values: string[]
  calldatas: string[]
  description: string
  descriptionHash: string
  status: string
  chains: string[]
}

export function Form() {
  const [targets, setTargets] = useState<string[]>([''])
  const [values, setValues] = useState<string[]>([''])
  const [calldatas, setCalldatas] = useState<string[]>([''])
  const [description, setDescription] = useState('')
  const [errors, setErrors] = useState<string[]>([])

  const handleAddField = () => {
    setTargets([...targets, ''])
    setValues([...values, ''])
    setCalldatas([...calldatas, ''])
  }

  const handleRemoveField = (index: number) => {
    setTargets(targets.filter((_, i) => i !== index))
    setValues(values.filter((_, i) => i !== index))
    setCalldatas(calldatas.filter((_, i) => i !== index))
  }

  const handleTargetChange = (index: number, value: string) => {
    const newTargets = [...targets]
    newTargets[index] = value
    setTargets(newTargets)
  }

  const handleValueChange = (index: number, value: string) => {
    const newValues = [...values]
    newValues[index] = value
    setValues(newValues)
  }

  const handleCalldataChange = (index: number, value: string) => {
    const newCalldatas = [...calldatas]
    newCalldatas[index] = value
    setCalldatas(newCalldatas)
  }

  const handleProposalSelect = (proposal: Proposal) => {
    setTargets(proposal.targets)
    setValues(proposal.values)
    setCalldatas(proposal.calldatas)
    setDescription(proposal.description)
  }

  const validateForm = () => {
    const newErrors: string[] = []

    if (targets.some((target) => !target)) {
      newErrors.push('All target addresses must be filled')
    }

    if (values.some((value) => !value)) {
      newErrors.push('All values must be filled')
    }

    if (calldatas.some((calldata) => !calldata)) {
      newErrors.push('All calldatas must be filled')
    }

    if (!description) {
      newErrors.push('Description is required')
    }

    setErrors(newErrors)
    return newErrors.length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (validateForm()) {
      // Handle form submission
      console.log({ targets, values, calldatas, description })
    }
  }

  return (
    <div className="max-w-6xl mx-auto p-8 min-h-screen bg-gray-50 dark:bg-gray-900 font-sans">
      <h1 className="text-center text-slate-800 dark:text-slate-200 mb-10 text-4xl font-bold tracking-tight">
        Governance Proposal Validator
      </h1>
      <form
        className="bg-white dark:bg-gray-800 p-10 rounded-2xl shadow-lg flex flex-col gap-10"
        onSubmit={handleSubmit}
      >
        <div className="mb-4 flex flex-col gap-5">
          <h2 className="text-slate-700 dark:text-slate-300 mb-2 text-xl font-semibold tracking-tight">
            Select Existing Proposal
          </h2>
          <ProposalList onSelectProposal={handleProposalSelect} />
        </div>

        <div className="mb-4 flex flex-col gap-5">
          <h2 className="text-slate-700 dark:text-slate-300 mb-2 text-xl font-semibold tracking-tight">
            Proposal Details
          </h2>
          {targets.map((_, index) => (
            <div
              key={index}
              className="grid grid-cols-3 gap-3 items-start w-full bg-gray-50 dark:bg-gray-700 p-3 rounded-lg transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-600"
            >
              <input
                type="text"
                placeholder="Target Address"
                value={targets[index]}
                onChange={(e) => handleTargetChange(index, e.target.value)}
                className={`w-full px-3 py-2 border border-slate-300 dark:border-gray-600 rounded-md font-mono text-sm whitespace-nowrap overflow-hidden text-ellipsis min-h-8 bg-white dark:bg-gray-800 text-slate-800 dark:text-slate-200 transition-all duration-200 placeholder:text-slate-400 dark:placeholder:text-gray-400 placeholder:text-xs focus:outline-none focus:border-blue-500 focus:shadow-[0_0_0_2px_rgba(59,130,246,0.1)] focus:whitespace-pre-wrap focus:break-all ${
                  errors.includes('All target addresses must be filled')
                    ? 'border-red-500 bg-red-50 dark:bg-red-900/20 focus:border-red-500 focus:shadow-[0_0_0_2px_rgba(239,68,68,0.1)]'
                    : ''
                }`}
              />
              <input
                type="text"
                placeholder="Value (in wei)"
                value={values[index]}
                onChange={(e) => handleValueChange(index, e.target.value)}
                className={`w-full px-3 py-2 border border-slate-300 dark:border-gray-600 rounded-md font-mono text-sm whitespace-nowrap overflow-hidden text-ellipsis min-h-8 bg-white dark:bg-gray-800 text-slate-800 dark:text-slate-200 transition-all duration-200 placeholder:text-slate-400 dark:placeholder:text-gray-400 placeholder:text-xs focus:outline-none focus:border-blue-500 focus:shadow-[0_0_0_2px_rgba(59,130,246,0.1)] focus:whitespace-pre-wrap focus:break-all ${
                  errors.includes('All values must be filled')
                    ? 'border-red-500 bg-red-50 dark:bg-red-900/20 focus:border-red-500 focus:shadow-[0_0_0_2px_rgba(239,68,68,0.1)]'
                    : ''
                }`}
              />
              <input
                type="text"
                placeholder="Calldata"
                value={calldatas[index]}
                onChange={(e) => handleCalldataChange(index, e.target.value)}
                className={`w-full px-3 py-2 border border-slate-300 dark:border-gray-600 rounded-md font-mono text-sm whitespace-nowrap overflow-hidden text-ellipsis min-h-8 bg-white dark:bg-gray-800 text-slate-800 dark:text-slate-200 transition-all duration-200 placeholder:text-slate-400 dark:placeholder:text-gray-400 placeholder:text-xs focus:outline-none focus:border-blue-500 focus:shadow-[0_0_0_2px_rgba(59,130,246,0.1)] focus:whitespace-pre-wrap focus:break-all ${
                  errors.includes('All calldatas must be filled')
                    ? 'border-red-500 bg-red-50 dark:bg-red-900/20 focus:border-red-500 focus:shadow-[0_0_0_2px_rgba(239,68,68,0.1)]'
                    : ''
                }`}
              />
              {index > 0 && (
                <button
                  type="button"
                  className="px-2.5 py-2.5 bg-red-500 text-white border-none rounded-lg cursor-pointer text-sm transition-all duration-200 hover:bg-red-600 hover:-translate-y-px active:translate-y-0"
                  onClick={() => handleRemoveField(index)}
                >
                  Remove
                </button>
              )}
            </div>
          ))}
          <button
            type="button"
            className="self-start px-5 py-2.5 bg-blue-500 text-white border-none rounded-lg cursor-pointer text-sm font-medium transition-all duration-200 hover:bg-blue-600 hover:-translate-y-px active:translate-y-0"
            onClick={handleAddField}
          >
            Add Target
          </button>
        </div>

        <div className="mb-4 flex flex-col gap-5">
          <h2 className="text-slate-700 dark:text-slate-300 mb-2 text-xl font-semibold tracking-tight">
            Description
          </h2>
          <textarea
            className="w-full min-h-[120px] px-4 py-3 border border-slate-300 dark:border-gray-600 rounded-lg resize-y font-inherit text-sm leading-6 text-slate-800 dark:text-slate-200 transition-all duration-200 focus:outline-none focus:border-blue-500 focus:shadow-[0_0_0_3px_rgba(59,130,246,0.1)]"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Enter proposal description"
          />
        </div>

        {errors.length > 0 && (
          <div className="text-red-500 text-sm mt-2 p-3 bg-red-50 dark:bg-red-900/20 rounded-lg border border-red-200 dark:border-red-800">
            {errors.map((error, index) => (
              <p key={index} className="m-0 py-1">
                {error}
              </p>
            ))}
          </div>
        )}

        <button
          type="submit"
          className="self-start px-5 py-2.5 bg-blue-500 text-white border-none rounded-lg cursor-pointer text-sm font-medium transition-all duration-200 hover:bg-blue-600 hover:-translate-y-px active:translate-y-0"
        >
          Validate Proposal
        </button>
      </form>
    </div>
  )
}
