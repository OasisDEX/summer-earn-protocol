import fs from 'node:fs'
import path from 'node:path'
/**
 * Retrieves available fleets for the current network from the deployments folder.
 * @param  networkName - The name of the current network.
 * @returns An array of fleet objects compatible with the current network.
 */
export function getAvailableFleets(networkName: string) {
  const deploymentsDir = path.resolve(__dirname, '..', '..', 'deployments')
  const files = fs.readdirSync(deploymentsDir).filter((file) => file.endsWith('_deployment.json'))

  return files
    .map((file) => {
      const content = JSON.parse(fs.readFileSync(path.join(deploymentsDir, file), 'utf8'))
      return { ...content, fileName: file }
    })
    .filter((fleet) => fleet.network === networkName)
}
