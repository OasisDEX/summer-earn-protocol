/**
 * Resolves role hashes to human-readable names.
 * This is done on the app side to allow for dynamic role resolution
 * without requiring subgraph redeployment.
 */

// Default admin role hash: 0x0000000000000000000000000000000000000000000000000000000000000000
const DEFAULT_ADMIN_ROLE_HASH = '0x0000000000000000000000000000000000000000000000000000000000000000'

// Role hash to name mapping
// This can be extended with dynamic roles in the future
const ROLE_HASH_TO_NAME: Record<string, string> = {
  [DEFAULT_ADMIN_ROLE_HASH]: 'DEFAULT_ADMIN_ROLE',
  // Add more role mappings here as needed
}

/**
 * Resolves a role hash to its human-readable name.
 * Returns the resolved name if found, otherwise returns null.
 */
export function resolveRoleName(roleHash: string): string | null {
  // Normalize hash to lowercase for comparison
  const normalizedHash = roleHash.toLowerCase()
  return ROLE_HASH_TO_NAME[normalizedHash] || null
}

/**
 * Resolves a role object's name field.
 * If the name is already resolved (doesn't start with "0x"), returns it as-is.
 * Otherwise, attempts to resolve the hash to a name.
 */
export function resolveRole(role: { name: string }): { name: string; resolved: boolean } {
  // If name doesn't start with "0x", it's already resolved
  if (!role.name.startsWith('0x')) {
    console.log(role.name)
    return { name: role.name, resolved: true }
  }

  // Try to resolve the hash
  const resolvedName = resolveRoleName(role.name)
  if (resolvedName) {
    return { name: resolvedName, resolved: true }
  }

  // Could not resolve
  return { name: role.name, resolved: false }
}
