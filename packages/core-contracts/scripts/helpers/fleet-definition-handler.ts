import fs from 'fs'
import path from 'path'

interface FleetDefinition {
  fleetName: string
  symbol: string
  assetSymbol: string
  arks: string[]
  initialMinimumFundsBufferBalance: string
  initialRebalanceCooldown: string
  depositCap: string
  initialTipRate: string
  minimumRateDifference: string
}

export function loadFleetDefinition(filePath: string): FleetDefinition {
  const fullPath = path.resolve(filePath)
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Fleet definition file not found: ${fullPath}`)
  }

  const fileContent = fs.readFileSync(fullPath, 'utf8')
  return JSON.parse(fileContent) as FleetDefinition
}
