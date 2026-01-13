import fs from 'fs'
import { globSync } from 'glob'
import path from 'path'
import { fileURLToPath } from 'url'

// ESM-compatible __dirname
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Chain ID to name mapping
const CHAIN_NAMES = {
  1: 'mainnet',
  146: 'sonic',
  42161: 'arbitrum',
  8453: 'base',
  999: 'hyperliquid',
}

// Source paths
const sourcePaths = {
  config: path.join(__dirname, '../../deployment/config/index.json'),
  deployments: path.join(__dirname, '../../deployment/ignition/deployments'),
}

// Target directory
const targetDir = path.join(__dirname, '../src/config/deployment')

try {
  // Ensure target directory exists
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true })
  }

  // Copy main config file
  const configData = fs.readFileSync(sourcePaths.config, 'utf8')
  fs.writeFileSync(path.join(targetDir, 'index.json'), configData)
  console.log('Successfully synced index.json from deployment config')

  // Find all deployed_addresses.json files
  const deploymentFiles = globSync('chain-*/deployed_addresses.json', {
    cwd: sourcePaths.deployments,
  })

  // Process each deployment file
  deploymentFiles.forEach((file) => {
    const chainId = file.match(/chain-(\d+)/)[1]
    const chainName = CHAIN_NAMES[chainId]

    if (chainName) {
      const sourcePath = path.join(sourcePaths.deployments, file)
      const targetPath = path.join(targetDir, 'deployed', `${chainName}.json`)
      const targetDeployedDir = path.join(targetDir, 'deployed')

      // Ensure deployed subdirectory exists
      if (!fs.existsSync(targetDeployedDir)) {
        fs.mkdirSync(targetDeployedDir, { recursive: true })
      }

      const deploymentData = fs.readFileSync(sourcePath, 'utf8')
      fs.writeFileSync(targetPath, deploymentData)
      console.log(`Successfully synced deployed_addresses for ${chainName} (chain ${chainId})`)
    } else {
      console.warn(`Warning: No name mapping found for chain ID ${chainId}`)
    }
  })

  console.log('All config files synced successfully')
} catch (error) {
  console.error('Error syncing config files:', error)
  process.exit(1)
}
