'use client'

import { useEffect, useId, useMemo, useRef, useState } from 'react'

import type { StrategyChartExecution } from '@/hooks/useStrategyChartData'
import type { PricePoint } from '@/lib/prices'

interface LineChartProps {
  prices: PricePoint[]
  gaps?: Array<[number, number]>
  executions?: StrategyChartExecution[]
  ceiling?: number
  floor?: number
  onCeilingChange?: (next: number) => void
  onFloorChange?: (next: number) => void
  interactive?: boolean
  height?: number
  className?: string
  // Used to label the "no data" message; e.g. "Price data begins May 14".
  dataStartsAt?: number
}

const PAD_L = 56
const PAD_R = 24
const PAD_T = 16
const PAD_B = 28

function formatPrice(p: number): string {
  if (!Number.isFinite(p)) return '—'
  if (p < 100) return `$${p.toFixed(2)}`
  return `$${Math.round(p).toLocaleString('en-US')}`
}

function formatDate(t: number): string {
  return new Date(t).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

// Port of design_files/chart.jsx → TS. Key extension: `gaps` breaks the line
// at each missing-data region instead of drawing a straight-line lie across
// it. Dragging handles call onCeilingChange/onFloorChange; the chart never
// invalidates the price-history query — guardrail state is local to the
// Detail page until the user saves.
export function LineChart({
  prices,
  gaps = [],
  executions = [],
  ceiling,
  floor,
  onCeilingChange,
  onFloorChange,
  interactive = true,
  height = 280,
  className = '',
  dataStartsAt,
}: LineChartProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(800)
  const [hover, setHover] = useState<PricePoint | null>(null)
  const [drag, setDrag] = useState<'ceiling' | 'floor' | null>(null)
  const gradIdRoot = useId().replace(/[:]/g, '')

  useEffect(() => {
    const node = containerRef.current
    if (!node) return
    const observer = new ResizeObserver((entries) => {
      setWidth(entries[0].contentRect.width)
    })
    observer.observe(node)
    return () => observer.disconnect()
  }, [])

  useEffect(() => {
    if (!drag) return
    const up = () => setDrag(null)
    window.addEventListener('mouseup', up)
    return () => window.removeEventListener('mouseup', up)
  }, [drag])

  const innerW = Math.max(0, width - PAD_L - PAD_R)
  const innerH = Math.max(0, height - PAD_T - PAD_B)
  const showEmpty = prices.length < 2

  const { yMin, yMax, x, y, yToP, t0, t1, segments } = useMemo(() => {
    if (showEmpty) {
      return {
        yMin: 0,
        yMax: 1,
        x: () => 0,
        y: () => 0,
        yToP: () => 0,
        t0: 0,
        t1: 0,
        segments: [] as PricePoint[][],
      }
    }
    const ps = prices.map((d) => d.p)
    const min = Math.min(...ps, floor ?? Infinity)
    const max = Math.max(...ps, ceiling ?? -Infinity)
    const span = max - min || 1
    const pad = span * 0.08
    const _yMin = min - pad
    const _yMax = max + pad
    const _t0 = prices[0].t
    const _t1 = prices[prices.length - 1].t
    const _x = (t: number) => PAD_L + ((t - _t0) / (_t1 - _t0 || 1)) * innerW
    const _y = (p: number) => PAD_T + (1 - (p - _yMin) / (_yMax - _yMin)) * innerH
    const _yToP = (yy: number) => _yMax - ((yy - PAD_T) / innerH) * (_yMax - _yMin)

    // Split prices into contiguous segments at each gap.
    const segs: PricePoint[][] = []
    let current: PricePoint[] = []
    let gi = 0
    for (let i = 0; i < prices.length; i++) {
      current.push(prices[i])
      const next = prices[i + 1]
      if (next && gi < gaps.length) {
        const g = gaps[gi]
        if (prices[i].t === g[0] && next.t === g[1]) {
          segs.push(current)
          current = []
          gi += 1
        }
      }
    }
    if (current.length > 0) segs.push(current)
    return {
      yMin: _yMin,
      yMax: _yMax,
      x: _x,
      y: _y,
      yToP: _yToP,
      t0: _t0,
      t1: _t1,
      segments: segs,
    }
  }, [prices, gaps, ceiling, floor, innerW, innerH, showEmpty])

  if (showEmpty) {
    return (
      <div
        ref={containerRef}
        className={['w-full', className].join(' ')}
        style={{ height }}
      >
        <div
          className="grid h-full place-items-center text-center text-sm text-[var(--text-3)]"
        >
          {dataStartsAt
            ? `Price data begins ${new Date(dataStartsAt).toLocaleDateString()}`
            : 'No price history available'}
        </div>
      </div>
    )
  }

  // Y axis ticks (4 intervals → 5 lines).
  const yTickCount = 4
  const yTicks: number[] = []
  for (let i = 0; i <= yTickCount; i++) {
    yTicks.push(yMin + (yMax - yMin) * (i / yTickCount))
  }
  const xTickCount = 4
  const xTickValues: number[] = []
  for (let i = 0; i <= xTickCount; i++) {
    xTickValues.push(t0 + ((t1 - t0) * i) / xTickCount)
  }

  const onMouseMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const rect = containerRef.current?.getBoundingClientRect()
    if (!rect) return
    const my = e.clientY - rect.top
    const mx = e.clientX - rect.left
    if (drag === 'ceiling') {
      const next = Math.max(yMin, Math.min(yMax, yToP(my)))
      onCeilingChange?.(next)
      return
    }
    if (drag === 'floor') {
      const next = Math.max(yMin, Math.min(yMax, yToP(my)))
      onFloorChange?.(next)
      return
    }
    if (mx < PAD_L || mx > width - PAD_R) {
      setHover(null)
      return
    }
    const ratio = (mx - PAD_L) / innerW
    const tHit = t0 + ratio * (t1 - t0)
    let best = prices[0]
    let bestDist = Math.abs(best.t - tHit)
    for (const p of prices) {
      const d = Math.abs(p.t - tHit)
      if (d < bestDist) {
        best = p
        bestDist = d
      }
    }
    setHover(best)
  }

  const isSkipped = (p: number): boolean =>
    (ceiling != null && p > ceiling) || (floor != null && p < floor)

  return (
    <div
      ref={containerRef}
      className={['relative w-full', drag ? 'select-none' : '', className].join(' ')}
      style={{ height }}
    >
      <svg
        width={width}
        height={height}
        viewBox={`0 0 ${width} ${height}`}
        onMouseMove={onMouseMove}
        onMouseLeave={() => setHover(null)}
        style={{ display: 'block', cursor: drag ? 'grabbing' : 'default' }}
      >
        <defs>
          <linearGradient id={`priceFill-${gradIdRoot}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--pink)" stopOpacity="0.18" />
            <stop offset="100%" stopColor="var(--pink)" stopOpacity="0" />
          </linearGradient>
          <linearGradient id={`dangerFill-${gradIdRoot}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--danger)" stopOpacity="0.10" />
            <stop offset="100%" stopColor="var(--danger)" stopOpacity="0" />
          </linearGradient>
        </defs>

        {/* Grid + Y labels */}
        {yTicks.map((tick, i) => (
          <g key={`yg-${i}`}>
            <line
              x1={PAD_L}
              x2={width - PAD_R}
              y1={y(tick)}
              y2={y(tick)}
              stroke="var(--border-faint)"
              strokeDasharray="2 4"
            />
            <text
              x={PAD_L - 10}
              y={y(tick) + 3}
              fontSize={10}
              textAnchor="end"
              fill="var(--text-3)"
              fontFamily="var(--font-mono)"
            >
              {formatPrice(tick)}
            </text>
          </g>
        ))}

        {/* X labels */}
        {xTickValues.map((tv, i) => (
          <text
            key={`xt-${i}`}
            x={x(tv)}
            y={height - 8}
            fontSize={10}
            textAnchor="middle"
            fill="var(--text-3)"
            fontFamily="var(--font-mono)"
          >
            {formatDate(tv)}
          </text>
        ))}

        {/* Skipped-zone overlays */}
        {ceiling != null && (
          <rect
            x={PAD_L}
            y={PAD_T}
            width={innerW}
            height={Math.max(0, y(ceiling) - PAD_T)}
            fill={`url(#dangerFill-${gradIdRoot})`}
          />
        )}
        {floor != null && (
          <rect
            x={PAD_L}
            y={y(floor)}
            width={innerW}
            height={Math.max(0, PAD_T + innerH - y(floor))}
            fill={`url(#dangerFill-${gradIdRoot})`}
          />
        )}

        {/* Area + line per contiguous segment */}
        {segments.map((seg, segIdx) => {
          if (seg.length < 2) return null
          const path = seg
            .map((d, i) => `${i === 0 ? 'M' : 'L'} ${x(d.t).toFixed(1)} ${y(d.p).toFixed(1)}`)
            .join(' ')
          const area = `${path} L ${x(seg[seg.length - 1].t).toFixed(1)} ${(PAD_T + innerH).toFixed(1)} L ${x(seg[0].t).toFixed(1)} ${(PAD_T + innerH).toFixed(1)} Z`
          return (
            <g key={`seg-${segIdx}`}>
              <path d={area} fill={`url(#priceFill-${gradIdRoot})`} />
              <path d={path} fill="none" stroke="var(--pink)" strokeWidth={1.8} />
            </g>
          )
        })}

        {/* Execution markers */}
        {executions.map((ex, i) => {
          const skipped = isSkipped(ex.p) || ex.skipped
          return (
            <g key={`ex-${i}`}>
              <line
                x1={x(ex.t)}
                x2={x(ex.t)}
                y1={PAD_T}
                y2={PAD_T + innerH}
                stroke="var(--border-faint)"
                strokeDasharray="1 3"
              />
              <circle
                cx={x(ex.t)}
                cy={y(ex.p)}
                r={5}
                fill={skipped ? 'var(--bg)' : 'var(--pink)'}
                stroke={skipped ? 'var(--text-3)' : 'var(--text)'}
                strokeWidth={1.5}
              />
            </g>
          )
        })}

        {/* Hover */}
        {hover && (
          <g>
            <line
              x1={x(hover.t)}
              x2={x(hover.t)}
              y1={PAD_T}
              y2={PAD_T + innerH}
              stroke="var(--text-2)"
              strokeDasharray="3 3"
              opacity={0.4}
            />
            <circle cx={x(hover.t)} cy={y(hover.p)} r={4} fill="var(--text)" />
          </g>
        )}

        {/* Ceiling / floor handles */}
        {ceiling != null && (
          <g
            style={{ cursor: interactive ? 'ns-resize' : 'default' }}
            onMouseDown={() => interactive && setDrag('ceiling')}
          >
            <line
              x1={PAD_L}
              x2={width - PAD_R}
              y1={y(ceiling)}
              y2={y(ceiling)}
              stroke="var(--danger)"
              strokeDasharray="4 4"
              strokeWidth={1.5}
            />
            <rect
              x={width - PAD_R - 90}
              y={y(ceiling) - 11}
              width={90}
              height={22}
              rx={11}
              fill="var(--bg-elev)"
              stroke="var(--danger)"
            />
            <text
              x={width - PAD_R - 45}
              y={y(ceiling) + 4}
              fontSize={11}
              textAnchor="middle"
              fill="var(--danger)"
              fontFamily="var(--font-mono)"
            >
              MAX {formatPrice(ceiling)}
            </text>
            {interactive && <circle cx={PAD_L + 8} cy={y(ceiling)} r={6} fill="var(--danger)" />}
          </g>
        )}
        {floor != null && (
          <g
            style={{ cursor: interactive ? 'ns-resize' : 'default' }}
            onMouseDown={() => interactive && setDrag('floor')}
          >
            <line
              x1={PAD_L}
              x2={width - PAD_R}
              y1={y(floor)}
              y2={y(floor)}
              stroke="var(--success)"
              strokeDasharray="4 4"
              strokeWidth={1.5}
            />
            <rect
              x={width - PAD_R - 90}
              y={y(floor) - 11}
              width={90}
              height={22}
              rx={11}
              fill="var(--bg-elev)"
              stroke="var(--success)"
            />
            <text
              x={width - PAD_R - 45}
              y={y(floor) + 4}
              fontSize={11}
              textAnchor="middle"
              fill="var(--success)"
              fontFamily="var(--font-mono)"
            >
              MIN {formatPrice(floor)}
            </text>
            {interactive && <circle cx={PAD_L + 8} cy={y(floor)} r={6} fill="var(--success)" />}
          </g>
        )}
      </svg>

      {hover && (
        <div
          className="pointer-events-none absolute z-10 rounded-md border border-[var(--border)] bg-[var(--bg-elev)] px-3 py-2 text-xs shadow-pop"
          style={{
            left: Math.min(width - 220, Math.max(PAD_L, x(hover.t) + 10)),
            top: 18,
          }}
        >
          <div className="font-mono text-[var(--text-3)]">
            {new Date(hover.t).toLocaleDateString(undefined, {
              month: 'short',
              day: 'numeric',
              year: 'numeric',
            })}
          </div>
          <div className="mt-1 font-mono text-sm">{formatPrice(hover.p)}</div>
        </div>
      )}
    </div>
  )
}
