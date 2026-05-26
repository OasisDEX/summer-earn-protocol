interface SegmentedOption<V extends string> {
  value: V
  label: React.ReactNode
}

interface SegmentedProps<V extends string> {
  options: SegmentedOption<V>[]
  value: V
  onChange: (value: V) => void
  className?: string
}

// Pill segmented control. The selected item gets an inset border + surface
// background; the others sit flat. One row, no overflow handling.
export function Segmented<V extends string>({
  options,
  value,
  onChange,
  className = '',
}: SegmentedProps<V>) {
  return (
    <div
      className={[
        'inline-flex gap-0.5 rounded-md border border-[var(--border-faint)] bg-[var(--surface)] p-[3px]',
        className,
      ].join(' ')}
    >
      {options.map((opt) => {
        const on = opt.value === value
        return (
          <button
            key={opt.value}
            type="button"
            onClick={() => onChange(opt.value)}
            className={[
              'rounded-[7px] border-none px-3.5 py-[7px] text-[13px] transition',
              on
                ? 'bg-[var(--surface-hover)] text-[var(--text)] shadow-[inset_0_0_0_1px_var(--border)]'
                : 'bg-transparent text-[var(--text-2)] hover:text-[var(--text)]',
            ].join(' ')}
          >
            {opt.label}
          </button>
        )
      })}
    </div>
  )
}
