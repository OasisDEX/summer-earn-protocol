'use client'

import { useMemo } from 'react'
import { fromHex } from 'viem'

import { useInstitutions } from '@/hooks/useInstitutions'
import type { ChainId } from '@/types'

import { labelBase, selectBase } from './ui'

interface InstitutionSelectorProps {
  chainId: ChainId
  value?: string
  onChange: (institutionId: string) => void
}

export function InstitutionSelector({ chainId, value, onChange }: InstitutionSelectorProps) {
  const { data: institutions = [], isLoading, error } = useInstitutions(chainId)

  const options = useMemo(() => {
    return institutions.map((i) => {
      let label = i.id
      if (typeof i.id === 'string' && i.id.startsWith('0x') && i.id.length === 66) {
        try {
          const decoded = fromHex(i.id as `0x${string}`, 'string')
          const NULL_CODE_POINT = 0x0
          let trimmed = decoded
          while (trimmed.length > 0 && trimmed.charCodeAt(trimmed.length - 1) === NULL_CODE_POINT) {
            trimmed = trimmed.slice(0, -1)
          }
          label = trimmed || i.id
        } catch (error) {
          console.error('Failed to decode institution id', error)
          // fallback to raw id
        }
      }
      return { id: i.id, label }
    })
  }, [institutions])

  return (
    <div>
      <label className={labelBase}>Institution</label>
      <select
        value={value ?? ''}
        onChange={(e) => onChange(e.target.value)}
        className={`${selectBase} w-full`}
        disabled={isLoading || !!error}
      >
        <option value="" disabled>
          {isLoading ? 'Loading institutions…' : 'Select an institution'}
        </option>
        {options.map((opt) => (
          <option key={opt.id} value={opt.id}>
            {opt.label}
          </option>
        ))}
      </select>
      {error && <p className="text-sm text-error mt-2">Failed to load institutions.</p>}
    </div>
  )
}
