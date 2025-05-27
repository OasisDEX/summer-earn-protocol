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

  const renderDecodedData = (index: number) => {
    const data = decodedData[index]
    if (!data) return null

    if ('dstEid' in data) {
      // Cross-chain data
      return (
        <div className={styles.decodedData}>
          <h4>Cross-chain Execution to {data.dstEid}</h4>
          {data.formattedProposals?.map((proposal, i) => (
            <div key={i} className={styles.proposal}>
              <div className={styles.proposalHeader}>
                <div className={styles.targetInfo}>
                  <span className={styles.label}>Target:</span>
                  <span className={styles.address}>{proposal.target}</span>
                  <span className={styles.contractName}>({proposal.targetName})</span>
                </div>
                <div className={styles.valueInfo}>
                  <span className={styles.label}>Value:</span>
                  <span className={styles.value}>{proposal.value} ETH</span>
                </div>
              </div>
              {proposal.decodedCall && (
                <div className={styles.decodedCall}>
                  <div className={styles.functionInfo}>
                    <span className={styles.label}>Function:</span>
                    <span className={styles.functionName}>{proposal.decodedCall.functionName}</span>
                  </div>
                  <div className={styles.arguments}>
                    <span className={styles.label}>Arguments:</span>
                    <ul className={styles.argsList}>
                      {proposal.decodedCall.args.map((arg: unknown, j: number) => {
                        const paramName = proposal.decodedCall?.paramNames?.[j] || `arg${j}`
                        return (
                          <li key={j}>
                            <span className={styles.paramName}>{paramName}:</span>{' '}
                            {formatArgValue(arg)}
                          </li>
                        )
                      })}
                    </ul>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )
    } else {
      // Regular function call
      const convertedArgs = convertBigIntToString(data.args)
      return (
        <div className={styles.decodedData}>
          <div className={styles.functionInfo}>
            <span className={styles.label}>Function:</span>
            <span className={styles.functionName}>{data.functionName}</span>
          </div>
          <div className={styles.arguments}>
            <span className={styles.label}>Arguments:</span>
            <ul className={styles.argsList}>
              {convertedArgs.map((arg: unknown, i: number) => {
                const paramName = data.paramNames?.[i] || `arg${i}`
                return (
                  <li key={i}>
                    <span className={styles.paramName}>{paramName}:</span> {formatArgValue(arg)}
                  </li>
                )
              })}
            </ul>
          </div>
        </div>
      )
    }
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
