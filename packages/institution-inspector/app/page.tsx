import { loadAllGraphs } from '@/lib/load-graph'
import { GraphExplorer } from '@/components/GraphExplorer'

export default function Page() {
  const graphs = loadAllGraphs()
  const count = Object.keys(graphs).length

  if (count === 0) {
    return (
      <main className="flex h-screen items-center justify-center p-8 text-center">
        <div>
          <h1 className="text-lg font-semibold text-on-surface">No graph data found</h1>
          <p className="mt-2 max-w-md text-sm text-on-surface-variant">
            Generate one first, e.g.{' '}
            <code className="rounded bg-surface-container px-1 py-0.5">pnpm generate -- --network base --env production</code>
          </p>
        </div>
      </main>
    )
  }

  return (
    <main className="h-screen w-screen">
      <GraphExplorer graphs={graphs} />
    </main>
  )
}
