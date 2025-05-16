import kleur from 'kleur'
import fs from 'node:fs'
import path from 'path'

export async function updateIndexJson<T extends Record<string, any>>(
  moduleType: string,
  network: string,
  deployedContracts: T,
  useBummerConfig: boolean = false,
) {
  const configFile = useBummerConfig ? 'index.test.json' : 'index.json'
  console.log(kleur.cyan().bold(`Updating ${configFile} with deployed ${moduleType} addresses...`))

  const indexPath = path.join(__dirname, '..', '..', 'config', configFile)
  let indexJson = JSON.parse(fs.readFileSync(indexPath, 'utf8'))

  if (!indexJson[network]) {
    indexJson[network] = { deployedContracts: {} }
  }

  if (!indexJson[network].deployedContracts[moduleType]) {
    indexJson[network].deployedContracts[moduleType] = {}
  }

  // Update addresses while preserving existing fields
  const existingConfig = indexJson[network].deployedContracts[moduleType] || {}

  // Create updated config by merging with existing config
  const updatedConfig = { ...existingConfig }

  // Update only the fields that were deployed
  Object.entries(deployedContracts).forEach(([key, value]) => {
    if (typeof value === 'object' && value.address) {
      updatedConfig[key] = {
        ...updatedConfig[key], // Preserve any existing fields
        address: value.address,
      }
    }
  })

  // Apply the merged config
  indexJson[network].deployedContracts[moduleType] = updatedConfig

  fs.writeFileSync(indexPath, JSON.stringify(indexJson, null, 2))
  console.log(kleur.green().bold(`${configFile} updated successfully!`))
}
