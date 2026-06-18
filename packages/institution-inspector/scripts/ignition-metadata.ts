import fs from 'node:fs'
import path from 'node:path'

/**
 * Parse a chain's Ignition deployment to map a deployed address back to its
 * contract metadata (futureId + contractName + inferred protocol). Pattern lifted
 * from packages/deployment/scripts/verify/by-future-filter.ts.
 *
 * Pass A enrichment only: turns a bare ark address into "AaveV3Ark / AaveV3".
 * Matching is by address, so the `staging_` futureId prefix is irrelevant here.
 */

export interface ContractMeta {
  futureId: string
  contractName?: string
  protocol?: string
}

export function inferProtocol(contractName?: string): string | undefined {
  if (!contractName) return undefined
  // e.g. "AaveV3Ark" -> "AaveV3", "MorphoVaultArk" -> "MorphoVault", "BufferArk" -> "Buffer"
  const m = contractName.match(/^(.*?)Ark$/)
  return m ? m[1] : undefined
}

/**
 * Build a lowercased address -> ContractMeta map for the given chain.
 * Returns an empty map (not an error) when the deployment dir is absent.
 */
export function loadIgnitionMetadata(
  deploymentRoot: string,
  chainId: number,
): Map<string, ContractMeta> {
  const out = new Map<string, ContractMeta>()
  const dir = path.join(deploymentRoot, 'ignition', 'deployments', `chain-${chainId}`)
  const addrFile = path.join(dir, 'deployed_addresses.json')
  if (!fs.existsSync(addrFile)) return out

  const addresses = JSON.parse(fs.readFileSync(addrFile, 'utf8')) as Record<string, string>
  const artifactsDir = path.join(dir, 'artifacts')

  for (const [futureId, address] of Object.entries(addresses)) {
    let contractName: string | undefined
    const artifactPath = path.join(artifactsDir, `${futureId}.json`)
    if (fs.existsSync(artifactPath)) {
      try {
        const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'))
        contractName = artifact.contractName
      } catch {
        /* ignore malformed artifact */
      }
    }
    // First writer wins per address; deployed_addresses has unique addresses anyway.
    out.set(address.toLowerCase(), {
      futureId,
      contractName,
      protocol: inferProtocol(contractName),
    })
  }
  return out
}
