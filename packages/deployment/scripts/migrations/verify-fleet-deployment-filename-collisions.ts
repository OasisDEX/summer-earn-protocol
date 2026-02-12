/**
 * Verifies that no two fleet config files would produce the same deployment filename.
 * Deployment filename = {sanitizedFleetName}_{network}_deployment.json
 * Collision occurs when two configs share the same (fleetName, network).
 *
 * Run: pnpm tsx scripts/migrations/verify-fleet-deployment-filename-collisions.ts
 */

import fs from 'node:fs'
import path from 'node:path'
import { FleetConfigFileSchema } from '../helpers/zod-schemas'

const DEPLOYMENT_ROOT = path.resolve(__dirname, '..', '..')
const CONFIG_FLEETS_DIR = path.join(DEPLOYMENT_ROOT, 'config', 'fleets')

function sanitizeFleetName(fleetName: string): string {
  return fleetName.replace(/\W/g, '')
}

function getDeploymentFileName(fleetName: string, network: string): string {
  return `${sanitizeFleetName(fleetName)}_${network}_deployment.json`
}

const deploymentKeyToConfigs = new Map<string, string[]>()

for (const file of fs.readdirSync(CONFIG_FLEETS_DIR).filter((f) => f.endsWith('.json'))) {
  const filePath = path.join(CONFIG_FLEETS_DIR, file)
  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8'))
  const result = FleetConfigFileSchema.safeParse(raw)
  if (!result.success) {
    console.error(`Config ${file}: parse failed - ${result.error.message}`)
    process.exit(1)
  }
  const deploymentFileName = getDeploymentFileName(result.data.fleetName, result.data.network)
  const existing = deploymentKeyToConfigs.get(deploymentFileName) ?? []
  existing.push(file)
  deploymentKeyToConfigs.set(deploymentFileName, existing)
}

const collisions = [...deploymentKeyToConfigs.entries()].filter(([, configs]) => configs.length > 1)

if (collisions.length > 0) {
  console.error('Deployment filename collision(s) detected:')
  for (const [deploymentFile, configFiles] of collisions) {
    console.error(`  ${deploymentFile} <- ${configFiles.join(', ')}`)
  }
  console.error('\nfleetName + network must be unique across config files.')
  process.exit(1)
}

console.log('No deployment filename collisions detected.')
process.exit(0)
