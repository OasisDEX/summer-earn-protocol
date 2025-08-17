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

  // Sanitize deployed contracts by converting any contract-like proxies
  // to plain objects containing only their address. This avoids JSON.stringify
  // interacting with viem proxies (which can trap property access like toJSON).
  const sanitize = (value: any): any => {
    if (Array.isArray(value)) return value.map(sanitize)
    if (value && typeof value === 'object') {
      if (typeof (value as any).address === 'string') {
        return { address: (value as any).address }
      }
      const result: Record<string, any> = {}
      for (const [k, v] of Object.entries(value)) {
        result[k] = sanitize(v)
      }
      return result
    }
    return value
  }

  const sanitizedContracts = sanitize(deployedContracts)

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
    sanitizedContracts,
  )

  fs.writeFileSync(indexPath, JSON.stringify(indexJson, null, 2))
  console.log(kleur.green().bold(`${configFile} updated successfully!`))
}
