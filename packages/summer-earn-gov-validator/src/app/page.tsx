'use client'

import { useState } from 'react'

import { Header } from '@/components/Header'
import { ProposalList } from '@/components/ProposalList'
import {
  CrossChainData,
  decodeCalldata,
  decodeCrossChainCalldata,
  isCrossChainExecution,
  validateCalldatas,
  validateTargets,
  validateValues,
} from '@/services/validation'

interface ValidationErrors {
  targets: string[]
  values: string[]
  calldatas: string[]
}

interface DecodedFunction {
  functionName: string
  args: any[]
  paramNames?: string[]
}

// Helper function to convert BigInt values to strings
const convertBigIntToString = (value: any): any => {
  if (typeof value === 'bigint') {
    return value.toString()
  }
  if (Array.isArray(value)) {
    return value.map(convertBigIntToString)
  }
  if (typeof value === 'object' && value !== null) {
    const result: any = {}
    for (const [key, val] of Object.entries(value)) {
      result[key] = convertBigIntToString(val)
    }
    return result
  }
  return value
}

export default function Home() {
  const [formData, setFormData] = useState({
    targets: [''],
    values: [''],
    calldatas: [''],
    description: '',
  })

  const [errors, setErrors] = useState<ValidationErrors>({
    targets: [],
    values: [],
    calldatas: [],
  })

  const [contractNames, setContractNames] = useState<string[]>([])
  const [decodedData, setDecodedData] = useState<(DecodedFunction | CrossChainData | null)[]>([])
  const [validatedExecutions, setValidatedExecutions] = useState<Set<string>>(new Set())

  const handleArrayInputChange = (
    index: number,
    field: 'targets' | 'values' | 'calldatas',
    value: string,
  ) => {
    const newArray = [...formData[field]]
    newArray[index] = value
    setFormData((prev) => ({
      ...prev,
      [field]: newArray,
    }))

    // If this is a target field, try to identify the contract
    if (field === 'targets') {
      const targetsValidation = validateTargets(newArray)
      setContractNames(targetsValidation.contractNames)
    }

    // If this is a calldata field, try to decode it
    if (field === 'calldatas') {
      const newDecodedData = [...decodedData]
      if (isCrossChainExecution(formData.targets[index], value)) {
        newDecodedData[index] = decodeCrossChainCalldata(value)
      } else {
        newDecodedData[index] = decodeCalldata(value)
      }
      setDecodedData(newDecodedData)
    }
  }

  const addArrayField = (field: 'targets' | 'values' | 'calldatas') => {
    setFormData((prev) => ({
      ...prev,
      [field]: [...prev[field], ''],
    }))
    if (field === 'calldatas') {
      setDecodedData([...decodedData, null])
    }
    if (field === 'targets') {
      setContractNames([...contractNames, ''])
    }
  }

  const removeArrayField = (field: 'targets' | 'values' | 'calldatas', index: number) => {
    setFormData((prev) => ({
      ...prev,
      [field]: prev[field].filter((_, i) => i !== index),
    }))
    if (field === 'calldatas') {
      setDecodedData(decodedData.filter((_, i) => i !== index))
    }
    if (field === 'targets') {
      setContractNames(contractNames.filter((_, i) => i !== index))
    }
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()

    // Validate all fields
    const targetsValidation = validateTargets(formData.targets)
    const valuesValidation = validateValues(formData.values)
    const calldatasValidation = validateCalldatas(formData.calldatas)

    // Update contract names
    setContractNames(targetsValidation.contractNames)

    // Check for cross-chain executions
    const hasCrossChainExecution = formData.targets.some((target, index) =>
      isCrossChainExecution(target, formData.calldatas[index]),
    )

    setErrors({
      targets: targetsValidation.errors,
      values: valuesValidation.errors,
      calldatas: calldatasValidation.errors,
    })

    if (targetsValidation.isValid && valuesValidation.isValid && calldatasValidation.isValid) {
      console.log('Form submitted:', formData)
      if (hasCrossChainExecution) {
        console.log('Cross-chain execution detected')
        // TODO: Handle cross-chain execution validation
      }
    }
  }

  // Helper function to truncate text with tooltip
  const TruncatedText = ({
    text,
    maxLength = 20,
    className = '',
  }: {
    text: string
    maxLength?: number
    className?: string
  }) => {
    if (text.length <= maxLength) {
      return <span className={className}>{text}</span>
    }

    return (
      <span
        className={`${className} cursor-help border-b border-dotted border-gray-400 dark:border-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 rounded px-0.5`}
        title={text}
      >
        {text.substring(0, maxLength)}...
      </span>
    )
  }

  // Helper function to format account display
  const formatAccountDisplay = (arg: any): React.ReactNode => {
    if (typeof arg === 'string' && arg.includes('#')) {
      // Format: mainnet:FleetModule_LazyVault_HigherRisk_USDC#FleetCommander(0xE9cDA459bED6dcfb8AC61CD8cE08E2D52370cB06)
      const parts = arg.split('#')
      if (parts.length === 2) {
        const [networkAndContract, roleAndAddress] = parts
        const addressMatch = roleAndAddress.match(/\(([^)]+)\)$/)
        const address = addressMatch ? addressMatch[1] : ''
        const role = addressMatch ? roleAndAddress.replace(/\([^)]+\)$/, '') : roleAndAddress

        return (
          <div className="flex flex-col gap-0.5">
            <div className="text-sm font-medium text-gray-900 dark:text-white leading-tight">
              <TruncatedText text={`${networkAndContract}#${role}`} maxLength={30} />
            </div>
            {address && (
              <div className="text-xs text-gray-500 dark:text-gray-400 font-mono leading-tight">
                <TruncatedText text={address} maxLength={20} />
              </div>
            )}
          </div>
        )
      }
    }

    if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 42) {
      return (
        <TruncatedText
          text={arg}
          maxLength={20}
          className="font-mono text-blue-600 dark:text-blue-400 text-sm"
        />
      )
    }

    if (typeof arg === 'object' && arg !== null) {
      return (
        <div className="flex flex-col gap-0.5">
          {Object.entries(arg).map(([key, value]) => (
            <div key={key}>
              {key}: {formatAccountDisplay(value)}
            </div>
          ))}
        </div>
      )
    }
    return <span>{String(arg)}</span>
  }

  const renderDecodedData = (index: number) => {
    const data = decodedData[index]
    if (!data) return null

    if ('dstEid' in data) {
      // Cross-chain data
      const executions = data.formattedProposals || []
      const sortedExecutions = executions.sort((a, b) => {
        const aId = `crosschain-${index}-${a.target}-${a.value}`
        const bId = `crosschain-${index}-${b.target}-${b.value}`
        const aValidated = validatedExecutions.has(aId)
        const bValidated = validatedExecutions.has(bId)

        if (aValidated && !bValidated) return 1
        if (!aValidated && bValidated) return -1
        return 0
      })

      return (
        <div className="mt-4 p-6 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-600">
          <h4 className="m-0 mb-5 text-gray-800 dark:text-gray-200 text-lg font-semibold">
            Cross-chain Execution to {data.dstEid}
          </h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            {sortedExecutions.map((proposal, i) => {
              const executionId = `crosschain-${index}-${proposal.target}-${proposal.value}-${i}`
              const isValidated = validatedExecutions.has(executionId)

              return (
                <div
                  key={executionId}
                  className={`bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg h-fit p-4 transition-all duration-200 hover:shadow-md ${
                    isValidated
                      ? 'opacity-60 bg-gray-50 dark:bg-gray-800 border-gray-300 dark:border-gray-500'
                      : ''
                  }`}
                >
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4 pb-3 border-b border-gray-100 dark:border-gray-600 items-start">
                    <div className="flex flex-col gap-1">
                      <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                        Target:
                      </div>
                      <div className="flex flex-col gap-0.5">
                        <TruncatedText
                          text={proposal.target}
                          maxLength={20}
                          className="font-mono text-blue-600 dark:text-blue-400 text-sm"
                        />
                        <div className="text-xs text-gray-500 dark:text-gray-400 italic">
                          <TruncatedText text={proposal.targetName} maxLength={25} />
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-col gap-1">
                      <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                        Value:
                      </div>
                      <div className="flex flex-col gap-0.5">
                        <span className="font-semibold text-green-600 dark:text-green-400 text-sm">
                          {proposal.value} ETH
                        </span>
                      </div>
                    </div>
                    <div className="flex items-center justify-end mt-2">
                      <label className="flex items-center gap-2 cursor-pointer text-xs text-gray-500 dark:text-gray-400 select-none">
                        <input
                          type="checkbox"
                          checked={isValidated}
                          onChange={() => toggleValidation(executionId)}
                          className="w-4 h-4 accent-blue-600 cursor-pointer"
                        />
                        <span
                          className={`font-medium transition-colors duration-200 ${isValidated ? 'text-green-600 dark:text-green-400 font-semibold' : ''}`}
                        >
                          Validated
                        </span>
                      </label>
                    </div>
                  </div>
                  {proposal.decodedCall && (
                    <div className="mt-3 pt-3 border-t-2 border-dashed border-gray-200 dark:border-gray-600">
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3 items-center">
                        <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                          Function:
                        </div>
                        <div className="flex flex-col gap-0.5">
                          <span className="font-mono text-purple-600 dark:text-purple-400 font-semibold text-sm">
                            {proposal.decodedCall.functionName}
                          </span>
                        </div>
                      </div>
                      <div className="flex flex-col gap-2">
                        <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                          Arguments:
                        </div>
                        <div
                          className={`grid gap-2 p-3 bg-gray-50 dark:bg-gray-800 rounded-md border border-gray-200 dark:border-gray-600 ${
                            proposal.decodedCall.args.length <= 2
                              ? 'grid-cols-1'
                              : 'grid-cols-1 md:grid-cols-2'
                          }`}
                        >
                          {proposal.decodedCall.args.map((arg: unknown, j: number) => {
                            const paramName = proposal.decodedCall?.paramNames?.[j] || `arg${j}`
                            return (
                              <div
                                key={j}
                                className="flex flex-col gap-0.5 p-2 bg-white dark:bg-gray-700 rounded border border-gray-200 dark:border-gray-600"
                              >
                                <span className="text-xs font-semibold text-gray-500 dark:text-gray-400 font-mono">
                                  {paramName}:
                                </span>
                                <div className="text-sm text-gray-900 dark:text-white break-all">
                                  {formatAccountDisplay(arg)}
                                </div>
                              </div>
                            )
                          })}
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )
    } else {
      // Regular function call - base proposal
      const convertedArgs = convertBigIntToString(data.args)
      const targetAddress = formData.targets[index]
      const contractName = contractNames[index] || 'Unknown Contract'
      const executionId = `base-${index}-${targetAddress}-${data.functionName}-${formData.values[index]}`
      const isValidated = validatedExecutions.has(executionId)

      return (
        <div className="mt-4 p-6 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-600">
          <h4 className="m-0 mb-5 text-gray-800 dark:text-gray-200 text-lg font-semibold">
            Base Proposal Execution
          </h4>
          <div
            key={executionId}
            className={`bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg h-fit p-4 transition-all duration-200 hover:shadow-md ${
              isValidated
                ? 'opacity-60 bg-gray-50 dark:bg-gray-800 border-gray-300 dark:border-gray-500'
                : ''
            }`}
          >
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4 pb-3 border-b border-gray-100 dark:border-gray-600 items-start">
              <div className="flex flex-col gap-1">
                <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                  Target:
                </div>
                <div className="flex flex-col gap-0.5">
                  <TruncatedText
                    text={targetAddress}
                    maxLength={20}
                    className="font-mono text-blue-600 dark:text-blue-400 text-sm"
                  />
                  <div className="text-xs text-gray-500 dark:text-gray-400 italic">
                    <TruncatedText text={contractName} maxLength={25} />
                  </div>
                </div>
              </div>
              <div className="flex flex-col gap-1">
                <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                  Value:
                </div>
                <div className="flex flex-col gap-0.5">
                  <span className="font-semibold text-green-600 dark:text-green-400 text-sm">
                    {formData.values[index]} ETH
                  </span>
                </div>
              </div>
              <div className="flex items-center justify-end mt-2">
                <label className="flex items-center gap-2 cursor-pointer text-xs text-gray-500 dark:text-gray-400 select-none">
                  <input
                    type="checkbox"
                    checked={isValidated}
                    onChange={() => toggleValidation(executionId)}
                    className="w-4 h-4 accent-blue-600 cursor-pointer"
                  />
                  <span
                    className={`font-medium transition-colors duration-200 ${isValidated ? 'text-green-600 dark:text-green-400 font-semibold' : ''}`}
                  >
                    Validated
                  </span>
                </label>
              </div>
            </div>
            <div className="mt-3 pt-3 border-t-2 border-dashed border-gray-200 dark:border-gray-600">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3 items-center">
                <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                  Function:
                </div>
                <div className="flex flex-col gap-0.5">
                  <span className="font-mono text-purple-600 dark:text-purple-400 font-semibold text-sm">
                    {data.functionName}
                  </span>
                </div>
              </div>
              <div className="flex flex-col gap-2">
                <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                  Arguments:
                </div>
                <div
                  className={`grid gap-2 p-3 bg-gray-50 dark:bg-gray-800 rounded-md border border-gray-200 dark:border-gray-600 ${
                    convertedArgs.length <= 2 ? 'grid-cols-1' : 'grid-cols-1 md:grid-cols-2'
                  }`}
                >
                  {convertedArgs.map((arg: unknown, i: number) => {
                    const paramName = data.paramNames?.[i] || `arg${i}`
                    return (
                      <div
                        key={i}
                        className="flex flex-col gap-0.5 p-2 bg-white dark:bg-gray-700 rounded border border-gray-200 dark:border-gray-600"
                      >
                        <span className="text-xs font-semibold text-gray-500 dark:text-gray-400 font-mono">
                          {paramName}:
                        </span>
                        <div className="text-sm text-gray-900 dark:text-white break-all">
                          {formatAccountDisplay(arg)}
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            </div>
          </div>
        </div>
      )
    }
  }

  const toggleValidation = (executionId: string) => {
    setValidatedExecutions((prev) => {
      const newSet = new Set(prev)
      if (newSet.has(executionId)) {
        newSet.delete(executionId)
      } else {
        newSet.add(executionId)
      }
      return newSet
    })
  }

  const handleProposalSelect = (proposal: any) => {
    setFormData({
      targets: proposal.targets,
      values: proposal.values,
      calldatas: proposal.calldatas,
      description: proposal.description,
    })

    // Update decoded data for each calldata
    const newDecodedData = proposal.calldatas.map((calldata: string, index: number) => {
      if (isCrossChainExecution(proposal.targets[index], calldata)) {
        return decodeCrossChainCalldata(calldata)
      }
      return decodeCalldata(calldata)
    })
    setDecodedData(newDecodedData)

    // Update contract names
    const targetsValidation = validateTargets(proposal.targets)
    setContractNames(targetsValidation.contractNames)

    // Clear validation state when selecting new proposal
    setValidatedExecutions(new Set())
  }

  return (
    <>
      <Header />
      <main className="max-w-6xl mx-auto p-8 min-h-screen bg-gray-50 dark:bg-gray-900">
        <h1 className="text-center text-gray-900 dark:text-white mb-10 text-4xl font-bold tracking-tight">
          Governance Proposal Validator
        </h1>
        <form
          onSubmit={handleSubmit}
          className="bg-white dark:bg-gray-800 p-10 rounded-2xl shadow-lg border border-gray-200 dark:border-gray-700 flex flex-col gap-10"
        >
          <div className="flex flex-col gap-5">
            <h2 className="text-gray-800 dark:text-gray-200 text-xl font-semibold tracking-tight">
              Select Existing Proposal
            </h2>
            <ProposalList onSelectProposal={handleProposalSelect} />
          </div>

          <div className="flex flex-col gap-5">
            <h2 className="text-gray-800 dark:text-gray-200 text-xl font-semibold tracking-tight">
              Target / Value / Calldata
            </h2>
            {formData.targets.map((target, index) => (
              <div
                key={`target-${index}`}
                className="grid grid-cols-1 md:grid-cols-3 gap-3 items-start w-full bg-gray-50 dark:bg-gray-700 p-3 rounded-lg transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-600"
              >
                <div className="flex flex-col w-full">
                  <input
                    type="text"
                    value={target}
                    onChange={(e) => handleArrayInputChange(index, 'targets', e.target.value)}
                    placeholder="0x..."
                    required
                    className={`w-full p-3 border rounded-md font-mono text-sm whitespace-nowrap overflow-hidden text-ellipsis min-h-8 bg-white dark:bg-gray-800 text-gray-900 dark:text-white transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                      errors.targets[index]
                        ? 'border-red-500 bg-red-50 dark:bg-red-900/20 focus:ring-red-500'
                        : 'border-gray-300 dark:border-gray-600'
                    }`}
                  />
                  {contractNames[index] && (
                    <span className="text-xs text-blue-600 dark:text-blue-400 mt-1 font-mono">
                      {contractNames[index]}
                    </span>
                  )}
                </div>
                <input
                  type="text"
                  value={formData.values[index]}
                  onChange={(e) => handleArrayInputChange(index, 'values', e.target.value)}
                  placeholder="Value in wei"
                  required
                  className={`w-full p-3 border rounded-md font-mono text-sm whitespace-nowrap overflow-hidden text-ellipsis min-h-8 bg-white dark:bg-gray-800 text-gray-900 dark:text-white transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                    errors.values[index]
                      ? 'border-red-500 bg-red-50 dark:bg-red-900/20 focus:ring-red-500'
                      : 'border-gray-300 dark:border-gray-600'
                  }`}
                />
                <input
                  type="text"
                  value={formData.calldatas[index]}
                  onChange={(e) => handleArrayInputChange(index, 'calldatas', e.target.value)}
                  placeholder="Calldata"
                  required
                  className={`w-full p-3 border rounded-md font-mono text-sm whitespace-nowrap overflow-hidden text-ellipsis min-h-8 bg-white dark:bg-gray-800 text-gray-900 dark:text-white transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                    errors.calldatas[index]
                      ? 'border-red-500 bg-red-50 dark:bg-red-900/20 focus:ring-red-500'
                      : 'border-gray-300 dark:border-gray-600'
                  }`}
                />
                {index > 0 && (
                  <button
                    type="button"
                    className="px-5 py-3 bg-red-600 text-white border-none rounded-lg cursor-pointer text-sm font-medium transition-all duration-200 hover:bg-red-700 active:transform active:translate-y-0"
                    onClick={() => removeArrayField('targets', index)}
                  >
                    Remove
                  </button>
                )}
              </div>
            ))}
            <button
              type="button"
              className="self-start px-5 py-3 bg-blue-600 text-white border-none rounded-lg cursor-pointer text-sm font-medium transition-all duration-200 hover:bg-blue-700 active:transform active:translate-y-0"
              onClick={() => addArrayField('targets')}
            >
              Add calldata
            </button>
          </div>

          {decodedData.some((data) => data !== null) && (
            <div className="flex flex-col gap-5">
              <h2 className="text-gray-800 dark:text-gray-200 text-xl font-semibold tracking-tight">
                Decoded Data
              </h2>
              {decodedData.map((data, index) => (
                <div key={`decoded-${index}`}>{renderDecodedData(index)}</div>
              ))}
            </div>
          )}

          <div className="flex flex-col gap-5">
            <h2 className="text-gray-800 dark:text-gray-200 text-xl font-semibold tracking-tight">
              Description
            </h2>
            <textarea
              className="w-full min-h-32 p-4 border border-gray-300 dark:border-gray-600 rounded-lg resize-y font-inherit text-sm leading-relaxed text-gray-900 dark:text-white transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-gray-800"
              value={formData.description}
              onChange={(e) =>
                setFormData((prev) => ({
                  ...prev,
                  description: e.target.value,
                }))
              }
              placeholder="Enter proposal description"
              required
            />
          </div>

          {Object.values(errors).some((errorArray) => errorArray.length > 0) && (
            <div className="text-red-600 dark:text-red-400 text-sm mt-2 p-3 bg-red-50 dark:bg-red-900/20 rounded-lg border border-red-200 dark:border-red-800">
              {Object.entries(errors).map(([field, errorArray]) =>
                errorArray.map((error: string, index: number) => (
                  <p key={`${field}-${index}`} className="m-0 py-1">
                    {error}
                  </p>
                )),
              )}
            </div>
          )}

          <button
            type="submit"
            className="px-5 py-3 bg-blue-600 text-white border-none rounded-lg cursor-pointer text-sm font-medium transition-all duration-200 hover:bg-blue-700 active:transform active:translate-y-0 self-start"
          >
            Validate Proposal
          </button>
        </form>
      </main>
    </>
  )
}
