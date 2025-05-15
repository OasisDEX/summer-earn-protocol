import { useState } from 'react';
import { ProposalList } from './ProposalList';
import styles from '../styles/Form.module.scss';

interface Proposal {
  id: string;
  targets: string[];
  values: string[];
  calldatas: string[];
  description: string;
  descriptionHash: string;
  status: string;
  chains: string[];
}

export function Form() {
  const [targets, setTargets] = useState<string[]>(['']);
  const [values, setValues] = useState<string[]>(['']);
  const [calldatas, setCalldatas] = useState<string[]>(['']);
  const [description, setDescription] = useState('');
  const [errors, setErrors] = useState<string[]>([]);

  const handleAddField = () => {
    setTargets([...targets, '']);
    setValues([...values, '']);
    setCalldatas([...calldatas, '']);
  };

  const handleRemoveField = (index: number) => {
    setTargets(targets.filter((_, i) => i !== index));
    setValues(values.filter((_, i) => i !== index));
    setCalldatas(calldatas.filter((_, i) => i !== index));
  };

  const handleTargetChange = (index: number, value: string) => {
    const newTargets = [...targets];
    newTargets[index] = value;
    setTargets(newTargets);
  };

  const handleValueChange = (index: number, value: string) => {
    const newValues = [...values];
    newValues[index] = value;
    setValues(newValues);
  };

  const handleCalldataChange = (index: number, value: string) => {
    const newCalldatas = [...calldatas];
    newCalldatas[index] = value;
    setCalldatas(newCalldatas);
  };

  const handleProposalSelect = (proposal: Proposal) => {
    setTargets(proposal.targets);
    setValues(proposal.values);
    setCalldatas(proposal.calldatas);
    setDescription(proposal.description);
  };

  const validateForm = () => {
    const newErrors: string[] = [];

    if (targets.some(target => !target)) {
      newErrors.push('All target addresses must be filled');
    }

    if (values.some(value => !value)) {
      newErrors.push('All values must be filled');
    }

    if (calldatas.some(calldata => !calldata)) {
      newErrors.push('All calldatas must be filled');
    }

    if (!description) {
      newErrors.push('Description is required');
    }

    setErrors(newErrors);
    return newErrors.length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (validateForm()) {
      // Handle form submission
      console.log({ targets, values, calldatas, description });
    }
  };

  return (
    <div className={styles.main}>
      <h1>Governance Proposal Validator</h1>
      <form className={styles.form} onSubmit={handleSubmit}>
        <div className={styles.section}>
          <h2>Select Existing Proposal</h2>
          <ProposalList onSelectProposal={handleProposalSelect} />
        </div>

        <div className={styles.section}>
          <h2>Proposal Details</h2>
          {targets.map((_, index) => (
            <div key={index} className={styles.arrayField}>
              <input
                type="text"
                placeholder="Target Address"
                value={targets[index]}
                onChange={(e) => handleTargetChange(index, e.target.value)}
                className={errors.includes('All target addresses must be filled') ? styles.error : ''}
              />
              <input
                type="text"
                placeholder="Value (in wei)"
                value={values[index]}
                onChange={(e) => handleValueChange(index, e.target.value)}
                className={errors.includes('All values must be filled') ? styles.error : ''}
              />
              <input
                type="text"
                placeholder="Calldata"
                value={calldatas[index]}
                onChange={(e) => handleCalldataChange(index, e.target.value)}
                className={errors.includes('All calldatas must be filled') ? styles.error : ''}
              />
              {index > 0 && (
                <button
                  type="button"
                  className={styles.removeButton}
                  onClick={() => handleRemoveField(index)}
                >
                  Remove
                </button>
              )}
            </div>
          ))}
          <button type="button" className={styles.addButton} onClick={handleAddField}>
            Add Target
          </button>
        </div>

        <div className={styles.section}>
          <h2>Description</h2>
          <textarea
            className={styles.textarea}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Enter proposal description"
          />
        </div>

        {errors.length > 0 && (
          <div className={styles.errorList}>
            {errors.map((error, index) => (
              <p key={index} className={styles.error}>
                {error}
              </p>
            ))}
          </div>
        )}

        <button type="submit" className={styles.addButton}>
          Validate Proposal
        </button>
      </form>
    </div>
  );
} 