import fs from 'fs'
import path from 'path'
import { FleetConfig } from '../../types/config-types'

export function loadFleetConfig(filePath: string): FleetConfig {
  const fullPath = path.resolve(filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Fleet definition file not found: ${fullPath}`)
  }

  const fileContent = fs.readFileSync(fullPath, 'utf8')
  const fleetConfig = JSON.parse(fileContent) as FleetConfig
  if (
    !fleetConfig.fleetName ||
    !fleetConfig.symbol ||
    !fleetConfig.assetSymbol ||
    !fleetConfig.initialMinimumBufferBalance ||
    !fleetConfig.initialRebalanceCooldown ||
    !fleetConfig.depositCap ||
    !fleetConfig.initialTipRate ||
    !fleetConfig.network ||
    fleetConfig.details === undefined
  ) {
    throw new Error(`Fleet config file is missing required fields: ${fullPath}`)
  }
  return fleetConfig
}
