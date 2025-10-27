import fs from 'node:fs'
import path from 'node:path'
import { DeployedBridge } from '../../types/bridge-types'

export function getBridgeDeploymentDir() {
  return path.join(process.cwd(), 'deployments', 'bridge')
}

export function getBridgeDeploymentFileName(network: string) {
  return `bridge-${network}.json`
}

export function getBridgeDeploymentPath(network: string) {
  return path.join(getBridgeDeploymentDir(), getBridgeDeploymentFileName(network))
}

export async function saveBridgeDeploymentJson(deployedBridge: DeployedBridge, network: string) {
  const deploymentsDir = getBridgeDeploymentDir()

  // Create directory if it doesn't exist
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true })
  }

  const filePath = getBridgeDeploymentPath(network)
  fs.writeFileSync(filePath, JSON.stringify(deployedBridge, null, 2))

  console.log(`Bridge deployment configuration saved to: ${filePath}`)
}
