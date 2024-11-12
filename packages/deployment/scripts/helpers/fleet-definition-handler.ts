import fs from 'fs'
import path from 'path'
import { FleetConfig } from '../../types/config-types'

export function loadFleetDefinition(filePath: string): Omit<FleetConfig, 'details'> {
  const fullPath = path.resolve(filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Fleet definition file not found: ${fullPath}`)
  }

  const fileContent = fs.readFileSync(fullPath, 'utf8')
  const fleetDefinition = JSON.parse(fileContent) as FleetConfig
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
