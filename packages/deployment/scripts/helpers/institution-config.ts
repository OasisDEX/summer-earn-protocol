import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import {
  InstitutionFleetEntry,
  InstitutionFleetEntrySchema,
  InstitutionIndex,
  InstitutionIndexSchema,
} from './zod-schemas'

export function getInstitutionRootDir(): string {
  return path.resolve(__dirname, '..', '..', 'config', 'institutions')
}

export function getInstitutionIndexPath(institutionId: string, useBummer: boolean): string {
  const filename = useBummer ? 'index.test.json' : 'index.json'
  return path.join(getInstitutionRootDir(), institutionId, filename)
}

export function ensureInstitutionIndexExists(institutionId: string, useBummer: boolean): string {
  const folder = path.join(getInstitutionRootDir(), institutionId)
  if (!fs.existsSync(folder)) fs.mkdirSync(folder, { recursive: true })
  const idxPath = getInstitutionIndexPath(institutionId, useBummer)
  if (!fs.existsSync(idxPath)) {
    fs.writeFileSync(idxPath, JSON.stringify({}, null, 2))
  }
  return idxPath
}

export function readInstitutionConfigFile(
  institutionId: string,
  useBummer: boolean,
): InstitutionIndex {
  const idxPath = ensureInstitutionIndexExists(institutionId, useBummer)
  const raw = fs.readFileSync(idxPath, 'utf8')
  let content: unknown = {}
  if (raw && raw.trim().length > 0) {
    try {
      content = JSON.parse(raw)
    } catch (e: any) {
      throw new Error(`Invalid JSON in institution index file at ${idxPath}. ${e?.message ?? ''}`)
    }
  } else {
    // Initialize empty JSON for empty files
    fs.writeFileSync(idxPath, JSON.stringify({}, null, 2))
  }
  const parsed = InstitutionIndexSchema.safeParse(content)
  if (!parsed.success) {
    console.error(kleur.red('Invalid institution index.json schema'), parsed.error)
    throw new Error('Invalid institution index.json')
  }
  return parsed.data
}

export function writeInstitutionIndex(
  institutionId: string,
  useBummer: boolean,
  updater: (current: InstitutionIndex) => InstitutionIndex,
): void {
  const idxPath = ensureInstitutionIndexExists(institutionId, useBummer)
  const current = readInstitutionConfigFile(institutionId, useBummer)
  const updated = updater(current)
  const rechecked = InstitutionIndexSchema.parse(updated)
  fs.writeFileSync(idxPath, JSON.stringify(rechecked, null, 2))
}

export function updateInstitutionDeployedContracts(
  institutionId: string,
  useBummer: boolean,
  network: string,
  module: 'gov' | 'core',
  contracts: Record<string, { address: string }>,
) {
  writeInstitutionIndex(institutionId, useBummer, (current) => {
    const next: InstitutionIndex = { ...current }
    const net = (next[network] as any) || {}
    const deployedContracts = (net.deployedContracts as any) || {}
    deployedContracts[module] = { ...contracts }
    ;(net as any).deployedContracts = deployedContracts
    next[network] = net
    return next
  })
}

export function updateInstitutionFleetEntry(
  institutionId: string,
  useBummer: boolean,
  network: string,
  fleetName: string,
  entry: InstitutionFleetEntry,
) {
  // Validate entry upfront for clearer errors
  InstitutionFleetEntrySchema.parse(entry)
  writeInstitutionIndex(institutionId, useBummer, (current) => {
    const next: InstitutionIndex = { ...current }
    const net = (next[network] as any) || {}
    const fleets = (net.fleets as any) || {}
    fleets[fleetName] = entry
    ;(net as any).fleets = fleets
    next[network] = net
    return next
  })
}

export function getInstitutionFleetConfigDir(institutionId: string): string {
  return path.resolve(getInstitutionRootDir(), institutionId, 'fleets')
}
