// Server-safe tab descriptor + builder. Kept separate from AdminTabs.tsx so
// admin server pages can compute the tab list without importing from a
// 'use client' module (Next 16 forbids invoking client functions from RSC).

export interface Tab {
  href: string
  label: string
}

export function buildAdminTabs(institutionSlug: string, fleetAddress: string): Tab[] {
  const root = `/institutions/${institutionSlug}/fleets/${fleetAddress}/admin`
  return [
    { href: `${root}/whitelist`, label: 'Whitelist' },
    { href: `${root}/rounds`, label: 'Rounds' },
    { href: `${root}/roles`, label: 'Roles' },
    { href: `${root}/rebalance`, label: 'Rebalance' },
  ]
}
