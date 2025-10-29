import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  InstitutionFleetEntry,
  InstitutionFleetEntrySchema,
  InstitutionGovernance,
  InstitutionGovernanceSchema,
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

/**
 * Reads and validates governance fields (treasury, governor[], guardian[]).
 * Throws if any of them are missing or invalid.
 */
export function readInstitutionGovernance(
  institutionId: string,
  useBummer: boolean,
  network: string,
): InstitutionGovernance {
  const content = readInstitutionConfigFile(institutionId, useBummer)
  const net = content[network]
  const treasury = net?.treasury
  const governor = net?.governor
  const guardian = net?.guardian

  // Strong validation using zod schema requiring all fields
  try {
    const parsed = InstitutionGovernanceSchema.parse({ treasury, governor, guardian })
    return {
      treasury: parsed.treasury as Address,
      governor: parsed.governor as Address[],
      guardian: parsed.guardian as Address[],
    }
  } catch (e) {
    throw new Error(
      `Institution governance is missing or invalid for network "${network}". Ensure fields { treasury, governor[], guardian[] } exist under that network in the institution index file for "${institutionId}"`,
    )
  }
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

/**
 * Lists institution ids (folder names) under config/institutions
 */
export function listInstitutionIds(): string[] {
  const rootDir = getInstitutionRootDir()
  if (!fs.existsSync(rootDir)) return []
  return fs
    .readdirSync(rootDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort()
}

/**
 * Prompts user to select an institution id from existing folders or enter manually.
 */
export async function promptForInstitutionId(): Promise<string | undefined> {
  const institutionFolders = listInstitutionIds()
  const { institutionIdChoice } = await prompts({
    type: 'select',
    name: 'institutionIdChoice',
    message: 'Select institution (or choose Manual Entry):',
    choices: [
      ...institutionFolders.map((name) => ({ title: name, value: name })),
      { title: 'Manual Entry', value: '__manual__' },
    ],
  })

  if (!institutionIdChoice) return undefined
  if (institutionIdChoice !== '__manual__') return institutionIdChoice

  const { manualId } = await prompts({
    type: 'text',
    name: 'manualId',
    message: 'Enter institution id (folder name under config/institutions):',
    validate: (v) => (v && /^[A-Za-z0-9_-]+$/.test(v) ? true : 'Invalid id'),
  })
  return manualId
}
