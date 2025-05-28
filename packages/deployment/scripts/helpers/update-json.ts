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

  // Recursively merge objects to handle nested structures
  const mergeObjects = (target: any, source: any): any => {
    for (const key in source) {
      if (typeof source[key] === 'object' && source[key] !== null) {
        if (source[key].address) {
          // If it's an object with an address, update it directly
          target[key] = { ...target[key], ...source[key] }
        } else {
          // Otherwise recursively merge deeper objects
          target[key] = target[key] || {}
          mergeObjects(target[key], source[key])
        }
      } else {
        // For non-objects, just copy the value
        target[key] = source[key]
      }
    }
    return target
  }

  // Apply the merged config
  indexJson[network].deployedContracts[moduleType] = mergeObjects(
    { ...existingConfig },
    deployedContracts,
  )

  fs.writeFileSync(indexPath, JSON.stringify(indexJson, null, 2))
  console.log(kleur.green().bold(`${configFile} updated successfully!`))
}
