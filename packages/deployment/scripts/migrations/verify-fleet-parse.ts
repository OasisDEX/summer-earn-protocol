/**
 * Verifies that all migrated fleet config and deployment JSON files parse successfully.
 * Run: pnpm tsx scripts/migrations/verify-fleet-parse.ts
 */

import fs from 'node:fs'
import path from 'node:path'
import { FleetConfigFileSchema, FleetDeploymentFileSchema } from '../helpers/zod-schemas'

const DEPLOYMENT_ROOT = path.resolve(__dirname, '..', '..')
const CONFIG_FLEETS_DIR = path.join(DEPLOYMENT_ROOT, 'config', 'fleets')
const DEPLOYMENTS_FLEETS_DIR = path.join(DEPLOYMENT_ROOT, 'deployments', 'fleets')

let errors = 0

for (const file of fs.readdirSync(CONFIG_FLEETS_DIR).filter((f) => f.endsWith('.json'))) {
  const filePath = path.join(CONFIG_FLEETS_DIR, file)
  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8'))
  const result = FleetConfigFileSchema.safeParse(raw)
  if (!result.success) {
    console.error(`Config ${file}:`, result.error.message)
    errors++
  }
}

for (const file of fs
  .readdirSync(DEPLOYMENTS_FLEETS_DIR)
  .filter((f) => f.endsWith('_deployment.json'))) {
  const filePath = path.join(DEPLOYMENTS_FLEETS_DIR, file)
  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8'))
  const result = FleetDeploymentFileSchema.safeParse(raw)
  if (!result.success) {
    console.error(`Deployment ${file}:`, result.error.message)
    errors++
  }
}

if (errors > 0) {
  console.error(`\n${errors} parse error(s)`)
  process.exit(1)
}
console.log('All fleet config and deployment files parse successfully.')
process.exit(0)
