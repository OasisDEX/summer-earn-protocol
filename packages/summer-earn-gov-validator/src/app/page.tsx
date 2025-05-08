'use client'

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
          <p>Targets:</p>
          <ul className={styles.targetsList}>
            {data.dstTargets.map((target, i) => (
              <li key={i}>
                <span className={styles.address}>{target}</span>
                <span className={styles.contractName}>{data.dstTargetNames[i]}</span>
              </li>
            ))}
          </ul>
          <p>Values: {data.dstValues.join(', ')}</p>
          <p>Description Hash: {data.dstDescriptionHash}</p>
          {data.decodedCalldatas && data.decodedCalldatas.length > 0 && (
            <div className={styles.nestedCalldatas}>
              <h5>Nested Proposals:</h5>
              {data.decodedCalldatas.map((decoded, i) => (
                <div key={i} className={styles.nestedCalldata}>
                  {decoded ? (
                    <>
                      <h6>Function: {decoded.functionName}</h6>
                      <p>
                        Arguments: {JSON.stringify(convertBigIntToString(decoded.args), null, 2)}
                      </p>
                    </>
                  ) : (
                    <p className={styles.error}>Could not decode calldata</p>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )
    } else {
      // Regular function call
      const convertedArgs = convertBigIntToString(data.args)
      return (
        <div className={styles.decodedData}>
          <h4>Function: {data.functionName}</h4>
          <p>Arguments: {JSON.stringify(convertedArgs, null, 2)}</p>
        </div>
      )
    }
  }

  return (
    <main className={styles.main}>
      <h1>Governance Proposal Validator</h1>
      <form onSubmit={handleSubmit} className={styles.form}>
        <div className={styles.section}>
          <h2>Targets (ETH Addresses)</h2>
          {formData.targets.map((target, index) => (
            <div key={`target-${index}`} className={styles.arrayField}>
              <div className={styles.inputWithLabel}>
                <input
                  type="text"
                  value={target}
                  onChange={(e) => handleArrayInputChange(index, 'targets', e.target.value)}
                  placeholder="0x..."
                  required
                  className={
                    errors.targets.some((err) => err.includes(`index ${index}`)) ? styles.error : ''
                  }
                />
                {contractNames[index] && contractNames[index] !== 'Unknown' && (
                  <span className={styles.contractLabel}>{contractNames[index]}</span>
                )}
              </div>
              {index > 0 && (
                <button
                  type="button"
                  onClick={() => removeArrayField('targets', index)}
                  className={styles.removeButton}
                >
                  Remove
                </button>
              )}
            </div>
          ))}
          {errors.targets.length > 0 && (
            <div className={styles.errorList}>
              {errors.targets.map((error, i) => (
                <p key={i} className={styles.error}>
                  {error}
                </p>
              ))}
            </div>
          )}
          <button
            type="button"
            onClick={() => addArrayField('targets')}
            className={styles.addButton}
          >
            Add Target
          </button>
        </div>

        <div className={styles.section}>
          <h2>Values (ETH Amounts)</h2>
          {formData.values.map((value, index) => (
            <div key={`value-${index}`} className={styles.arrayField}>
              <input
                type="number"
                value={value}
                onChange={(e) => handleArrayInputChange(index, 'values', e.target.value)}
                placeholder="0"
                required
                className={
                  errors.values.some((err) => err.includes(`index ${index}`)) ? styles.error : ''
                }
              />
              {index > 0 && (
                <button
                  type="button"
                  onClick={() => removeArrayField('values', index)}
                  className={styles.removeButton}
                >
                  Remove
                </button>
              )}
            </div>
          ))}
          {errors.values.length > 0 && (
            <div className={styles.errorList}>
              {errors.values.map((error, i) => (
                <p key={i} className={styles.error}>
                  {error}
                </p>
              ))}
            </div>
          )}
          <button
            type="button"
            onClick={() => addArrayField('values')}
            className={styles.addButton}
          >
            Add Value
          </button>
        </div>

        <div className={styles.section}>
          <h2>Calldatas (Bytes)</h2>
          {formData.calldatas.map((calldata, index) => (
            <div key={`calldata-${index}`} className={styles.arrayField}>
              <input
                type="text"
                value={calldata}
                onChange={(e) => handleArrayInputChange(index, 'calldatas', e.target.value)}
                placeholder="0x..."
                required
                className={
                  errors.calldatas.some((err) => err.includes(`index ${index}`)) ? styles.error : ''
                }
              />
              {index > 0 && (
                <button
                  type="button"
                  onClick={() => removeArrayField('calldatas', index)}
                  className={styles.removeButton}
                >
                  Remove
                </button>
              )}
              {renderDecodedData(index)}
            </div>
          ))}
          {errors.calldatas.length > 0 && (
            <div className={styles.errorList}>
              {errors.calldatas.map((error, i) => (
                <p key={i} className={styles.error}>
                  {error}
                </p>
              ))}
            </div>
          )}
          <button
            type="button"
            onClick={() => addArrayField('calldatas')}
            className={styles.addButton}
          >
            Add Calldata
          </button>
        </div>

        <div className={styles.section}>
          <h2>Description</h2>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData((prev) => ({ ...prev, description: e.target.value }))}
            placeholder="Enter proposal description..."
            required
            className={styles.textarea}
          />
        </div>

        <button type="submit" className={styles.submitButton}>
          Validate Proposal
        </button>
      </form>
    </main>
  )
}
