import fs from 'fs'
import path from 'path'
import { FleetDefinition } from '../../types/config-types'

export function loadFleetDefinition(filePath: string): Omit<FleetDefinition, 'details'> {
  const fullPath = path.resolve(filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Fleet definition file not found: ${fullPath}`)
  }

  const fileContent = fs.readFileSync(fullPath, 'utf8')
  const fleetDefinition = JSON.parse(fileContent) as FleetDefinition
  if (
    !fleetDefinition.fleetName ||
    !fleetDefinition.symbol ||
    !fleetDefinition.assetSymbol ||
    !fleetDefinition.initialMinimumBufferBalance ||
    !fleetDefinition.initialRebalanceCooldown ||
    !fleetDefinition.depositCap ||
    !fleetDefinition.initialTipRate ||
    !fleetDefinition.network
  ) {
    throw new Error(`Fleet definition file is missing required fields: ${fullPath}`)
  }
  return fleetDefinition
}
