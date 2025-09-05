'use client'

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
import styles from '@/styles/Form.module.scss'
import { useState } from 'react'

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

// Helper function to format argument value
const formatArgValue = (arg: any): React.ReactNode => {
  if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 42) {
    return <span className={styles.address}>{arg}</span>
  }
  if (typeof arg === 'object' && arg !== null) {
    if (Array.isArray(arg)) {
      return (
        <ul className={styles.nestedArgsList}>
          {arg.map((value, index) => (
            <li key={index}>
              <span className={styles.paramName}>{index}:</span> {formatArgValue(value)}
            </li>
          ))}
        </ul>
      )
    }
    return (
      <ul className={styles.nestedArgsList}>
        {Object.entries(arg).map(([key, value]) => (
          <li key={key}>
            <span className={styles.paramName}>{key}:</span> {formatArgValue(value)}
          </li>
        ))}
      </ul>
    )
  }
  return <span>{String(arg)}</span>
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
      <span className={`${className} ${styles.truncatedText}`} title={text}>
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
          <div className={styles.accountDisplay}>
            <div className={styles.accountName}>
              <TruncatedText text={`${networkAndContract}#${role}`} maxLength={30} />
            </div>
            {address && (
              <div className={styles.accountAddress}>
                <TruncatedText text={address} maxLength={20} />
              </div>
            )}
          </div>
        )
      }
    }

    if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 42) {
      return <TruncatedText text={arg} maxLength={20} className={styles.address} />
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
        <div className={styles.decodedData}>
          <h4>Cross-chain Execution to {data.dstEid}</h4>
          <div className={styles.executionsGrid}>
            {sortedExecutions.map((proposal, i) => {
              const executionId = `crosschain-${index}-${proposal.target}-${proposal.value}-${i}`
              const isValidated = validatedExecutions.has(executionId)

              return (
                <div
                  key={executionId}
                  className={`${styles.compactProposal} ${isValidated ? styles.validatedExecution : ''}`}
                >
                  <div className={styles.compactProposalHeader}>
                    <div className={styles.compactTargetInfo}>
                      <div className={styles.compactLabel}>Target:</div>
                      <div className={styles.compactValue}>
                        <TruncatedText
                          text={proposal.target}
                          maxLength={20}
                          className={styles.address}
                        />
                        <div className={styles.contractNameCompact}>
                          <TruncatedText text={proposal.targetName} maxLength={25} />
                        </div>
                      </div>
                    </div>
                    <div className={styles.compactValueInfo}>
                      <div className={styles.compactLabel}>Value:</div>
                      <div className={styles.compactValue}>
                        <span className={styles.value}>{proposal.value} ETH</span>
                      </div>
                    </div>
                    <div className={styles.validationCheckbox}>
                      <label className={styles.checkboxLabel}>
                        <input
                          type="checkbox"
                          checked={isValidated}
                          onChange={() => toggleValidation(executionId)}
                          className={styles.checkbox}
                        />
                        <span className={styles.checkboxText}>Validated</span>
                      </label>
                    </div>
                  </div>
                  {proposal.decodedCall && (
                    <div className={styles.compactDecodedCall}>
                      <div className={styles.compactFunctionInfo}>
                        <div className={styles.compactLabel}>Function:</div>
                        <div className={styles.compactValue}>
                          <span className={styles.functionName}>
                            {proposal.decodedCall.functionName}
                          </span>
                        </div>
                      </div>
                      <div className={styles.compactArguments}>
                        <div className={styles.compactLabel}>Arguments:</div>
                        <div
                          className={`${styles.compactArgsContainer} ${proposal.decodedCall.args.length <= 2 ? styles.singleColumn : ''}`}
                        >
                          {proposal.decodedCall.args.map((arg: unknown, j: number) => {
                            const paramName = proposal.decodedCall?.paramNames?.[j] || `arg${j}`
                            return (
                              <div key={j} className={styles.compactArgItem}>
                                <span className={styles.paramNameCompact}>{paramName}:</span>
                                <div className={styles.argValue}>{formatAccountDisplay(arg)}</div>
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
        <div className={styles.decodedData}>
          <h4>Base Proposal Execution</h4>
          <div
            key={executionId}
            className={`${styles.compactProposal} ${isValidated ? styles.validatedExecution : ''}`}
          >
            <div className={styles.compactProposalHeader}>
              <div className={styles.compactTargetInfo}>
                <div className={styles.compactLabel}>Target:</div>
                <div className={styles.compactValue}>
                  <TruncatedText text={targetAddress} maxLength={20} className={styles.address} />
                  <div className={styles.contractNameCompact}>
                    <TruncatedText text={contractName} maxLength={25} />
                  </div>
                </div>
              </div>
              <div className={styles.compactValueInfo}>
                <div className={styles.compactLabel}>Value:</div>
                <div className={styles.compactValue}>
                  <span className={styles.value}>{formData.values[index]} ETH</span>
                </div>
              </div>
              <div className={styles.validationCheckbox}>
                <label className={styles.checkboxLabel}>
                  <input
                    type="checkbox"
                    checked={isValidated}
                    onChange={() => toggleValidation(executionId)}
                    className={styles.checkbox}
                  />
                  <span className={styles.checkboxText}>Validated</span>
                </label>
              </div>
            </div>
            <div className={styles.compactDecodedCall}>
              <div className={styles.compactFunctionInfo}>
                <div className={styles.compactLabel}>Function:</div>
                <div className={styles.compactValue}>
                  <span className={styles.functionName}>{data.functionName}</span>
                </div>
              </div>
              <div className={styles.compactArguments}>
                <div className={styles.compactLabel}>Arguments:</div>
                <div
                  className={`${styles.compactArgsContainer} ${convertedArgs.length <= 2 ? styles.singleColumn : ''}`}
                >
                  {convertedArgs.map((arg: unknown, i: number) => {
                    const paramName = data.paramNames?.[i] || `arg${i}`
                    return (
                      <div key={i} className={styles.compactArgItem}>
                        <span className={styles.paramNameCompact}>{paramName}:</span>
                        <div className={styles.argValue}>{formatAccountDisplay(arg)}</div>
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
      <main className={styles.main}>
        <h1>Governance Proposal Validator</h1>
        <form onSubmit={handleSubmit} className={styles.form}>
          <div className={styles.section}>
            <h2>Select Existing Proposal</h2>
            <ProposalList onSelectProposal={handleProposalSelect} />
          </div>

          <div className={styles.section}>
            <h2>Target / Value / Calldata</h2>
            {formData.targets.map((target, index) => (
              <div key={`target-${index}`} className={styles.arrayField}>
                <div className={styles.inputWithLabel}>
                  <input
                    type="text"
                    value={target}
                    onChange={(e) => handleArrayInputChange(index, 'targets', e.target.value)}
                    placeholder="0x..."
                    required
                    className={errors.targets[index] ? styles.error : ''}
                  />
                  {contractNames[index] && (
                    <span className={styles.contractLabel}>{contractNames[index]}</span>
                  )}
                </div>
                <input
                  type="text"
                  value={formData.values[index]}
                  onChange={(e) => handleArrayInputChange(index, 'values', e.target.value)}
                  placeholder="Value in wei"
                  required
                  className={errors.values[index] ? styles.error : ''}
                />
                <input
                  type="text"
                  value={formData.calldatas[index]}
                  onChange={(e) => handleArrayInputChange(index, 'calldatas', e.target.value)}
                  placeholder="Calldata"
                  required
                  className={errors.calldatas[index] ? styles.error : ''}
                />
                {index > 0 && (
                  <button
                    type="button"
                    className={styles.removeButton}
                    onClick={() => removeArrayField('targets', index)}
                  >
                    Remove
                  </button>
                )}
              </div>
            ))}
            <button
              type="button"
              className={styles.addButton}
              onClick={() => addArrayField('targets')}
            >
              Add calldata
            </button>
          </div>

          {decodedData.some((data) => data !== null) && (
            <div className={styles.section}>
              <h2>Decoded Data</h2>
              {decodedData.map((data, index) => (
                <div key={`decoded-${index}`}>{renderDecodedData(index)}</div>
              ))}
            </div>
          )}

          <div className={styles.section}>
            <h2>Description</h2>
            <textarea
              className={styles.textarea}
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
            <div className={styles.errorList}>
              {Object.entries(errors).map(([field, errorArray]) =>
                errorArray.map((error: string, index: number) => (
                  <p key={`${field}-${index}`} className={styles.error}>
                    {error}
                  </p>
                )),
              )}
            </div>
          )}

          <button type="submit" className={styles.addButton}>
            Validate Proposal
          </button>
        </form>
      </main>
    </>
  )
}
