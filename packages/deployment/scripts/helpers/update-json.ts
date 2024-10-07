import kleur from 'kleur'
import fs from 'node:fs'
import path from 'path'

export async function updateIndexJson<T extends Record<string, any>>(
  moduleType: string,
  network: string,
  deployedContracts: T,
) {
  console.log(kleur.cyan().bold(`Updating index.json with deployed ${moduleType} addresses...`))

  const indexPath = path.join(__dirname, '..', '..', 'config', 'index.json')
  let indexJson = JSON.parse(fs.readFileSync(indexPath, 'utf8'))

  if (!indexJson[network]) {
    indexJson[network] = { deployedContracts: {} }
  }

  // Update the addresses in the index.json
  indexJson[network].deployedContracts[moduleType] = Object.entries(deployedContracts).reduce(
    (acc, [key, value]) => {
      if (typeof value === 'object' && value.address) {
        acc[key] = { address: value.address }
      }
      return acc
    },
    {} as Record<string, { address: string }>,
  )

  fs.writeFileSync(indexPath, JSON.stringify(indexJson, null, 2))
  console.log(kleur.green().bold('index.json updated successfully!'))
}
