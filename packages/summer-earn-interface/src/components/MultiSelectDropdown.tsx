'use client'

import { useCallback, useEffect, useRef, useState } from 'react'

export interface MultiSelectOption {
  id: string
  label: string
}

interface MultiSelectDropdownProps {
  options: MultiSelectOption[]
  selected: string[]
  onChange: (ids: string[]) => void
  placeholder?: string
}

export const MultiSelectDropdown = ({
  options,
  selected,
  onChange,
  placeholder = 'Select products…',
}: MultiSelectDropdownProps) => {
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const ref = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  // Close on click outside
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  // Focus input when dropdown opens
  useEffect(() => {
    if (open && inputRef.current) {
      inputRef.current.focus()
    }
  }, [open])

  const filtered = options.filter((o) => o.label.toLowerCase().includes(search.toLowerCase()))

  const toggle = useCallback(
    (id: string) => {
      onChange(selected.includes(id) ? selected.filter((s) => s !== id) : [...selected, id])
    },
    [selected, onChange],
  )

  const selectedLabels = options.filter((o) => selected.includes(o.id))

  return (
    <div ref={ref} className="relative w-full">
      {/* Trigger */}
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="w-full flex items-center gap-2 px-4 py-2.5 rounded-lg
          bg-[#1e2022] border border-white/[0.06] text-sm font-medium
          hover:bg-[#2b2c2f] transition-colors cursor-pointer text-left min-h-[42px]"
      >
        {selectedLabels.length === 0 ? (
          <span className="text-[#ababad] flex-1">{placeholder}</span>
        ) : (
          <span className="flex-1 flex flex-wrap gap-1.5 items-center">
            {selectedLabels.slice(0, 3).map((o) => (
              <span
                key={o.id}
                className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-[#89acff]/15 text-[#89acff] text-xs font-semibold"
              >
                {o.label.length > 20 ? o.label.slice(0, 20) + '…' : o.label}
                <span
                  role="button"
                  onClick={(e) => {
                    e.stopPropagation()
                    toggle(o.id)
                  }}
                  className="ml-0.5 hover:text-white cursor-pointer"
                >
                  ×
                </span>
              </span>
            ))}
            {selectedLabels.length > 3 && (
              <span className="text-xs text-[#ababad]">+{selectedLabels.length - 3} more</span>
            )}
          </span>
        )}
        <svg
          className={`w-4 h-4 text-[#ababad] transition-transform ${open ? 'rotate-180' : ''}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {/* Dropdown panel */}
      {open && (
        <div className="absolute z-dropdown mt-2 w-full rounded-xl bg-surface-container border border-white/[0.08] shadow-2xl shadow-black/50 overflow-hidden animate-in fade-in slide-in-from-top-1 duration-150">
          {/* Search */}
          <div className="p-3 border-b border-white/[0.06]">
            <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-[#121316] border border-white/[0.06]">
              <svg
                className="w-4 h-4 text-[#757578] shrink-0"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
              <input
                ref={inputRef}
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search products…"
                className="bg-transparent border-none outline-none text-sm text-white placeholder:text-[#757578] w-full"
              />
              {search && (
                <button
                  onClick={() => setSearch('')}
                  className="text-[#757578] hover:text-white text-xs"
                >
                  ✕
                </button>
              )}
            </div>
          </div>

          {/* Actions bar */}
          {selected.length > 0 && (
            <div className="px-3 py-2 border-b border-white/[0.06] flex items-center justify-between">
              <span className="text-[10px] font-semibold uppercase tracking-widest text-[#ababad]">
                {selected.length} selected
              </span>
              <button
                onClick={() => onChange([])}
                className="text-[10px] font-semibold uppercase tracking-wider text-[#ff716c] hover:text-[#ff9a97] transition-colors"
              >
                Clear all
              </button>
            </div>
          )}

          {/* Options list */}
          <div className="max-h-64 overflow-y-auto py-1 scrollbar-thin">
            {filtered.length === 0 ? (
              <div className="px-4 py-6 text-center text-sm text-[#757578]">
                No products match &quot;{search}&quot;
              </div>
            ) : (
              filtered.map((option) => {
                const isSelected = selected.includes(option.id)
                return (
                  <button
                    key={option.id}
                    type="button"
                    onClick={() => toggle(option.id)}
                    className={`w-full flex items-center gap-3 px-4 py-2.5 text-left text-sm transition-colors
                      ${isSelected ? 'bg-[#89acff]/[0.08] text-white' : 'text-[#ababad] hover:bg-white/[0.04] hover:text-white'}`}
                  >
                    {/* Checkbox */}
                    <span
                      className={`w-4 h-4 rounded border-2 flex items-center justify-center shrink-0 transition-all
                        ${isSelected ? 'bg-[#89acff] border-[#89acff]' : 'border-[#47484a] bg-transparent'}`}
                    >
                      {isSelected && (
                        <svg
                          className="w-3 h-3 text-white"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                          strokeWidth={3}
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                      )}
                    </span>
                    <span className="font-medium truncate">{option.label}</span>
                  </button>
                )
              })
            )}
          </div>
        </div>
      )}
    </div>
  )
}
