// Static directory of institutions + their fleets + rounds-vaults.
// Mirrors packages/deployment/config/institutions/<name>/index.test.json
// (and the production index.json once that exists). Addresses are inlined to
// avoid coupling Next bundling to the deployment workspace package; refresh
// these by hand when the registry is redeployed.

import { base } from 'wagmi/chains'

import type { ChainId } from '@/types/chain'

export interface InstitutionFleet {
  /** Display key from the deployment JSON. */
  key: string
  /** Friendly label rendered in lists/breadcrumbs. */
  label: string
  /** FleetCommander address (target vault of the rounds-vault pair). */
  fleetCommander: `0x${string}`
  bufferArk: `0x${string}`
  arks: `0x${string}`[]
  /** Input rounds-vault (USDC -> Fleet shares queue). */
  roundsVaultInput?: `0x${string}`
  /** Output rounds-vault (Fleet shares -> USDC queue). */
  roundsVaultOutput?: `0x${string}`
}

export interface Institution {
  /** URL slug used in routes. */
  slug: string
  displayName: string
  chainId: ChainId
  /** Gov + core contracts shared by every fleet under this institution. */
  protocolAccessManager: `0x${string}`
  configurationManager: `0x${string}`
  harborCommand: `0x${string}`
  admiralsQuarters: `0x${string}`
  raft: `0x${string}`
  tipJar: `0x${string}`
  /** Off-chain role assignments encoded in the deployment JSON. */
  treasury: `0x${string}`
  governors: `0x${string}`[]
  guardians: `0x${string}`[]
  superKeeper: `0x${string}`
  whitelistManagers: `0x${string}`[]
  fleets: InstitutionFleet[]
}

export const INSTITUTIONS: Institution[] = [
  {
    slug: 'extdemocorp-v2',
    displayName: 'ExtDemoCorp v2',
    chainId: String(base.id) as ChainId,
    protocolAccessManager: '0x0eF127ce2ae77e7a08Dc4Bb460e6E888E86D0459',
    configurationManager: '0x40998DbBA04E0b85Ec2851ce77198E664Be1dcAE',
    harborCommand: '0x43fff3FB7e97b4d2bAE41fA899dD0E49Be0497c2',
    admiralsQuarters: '0x9E74A42EfBEfb2360B948DA27292346321e7bA9E',
    raft: '0x318c9C76f8d2Be642f01A873A93aDcB63fBcb5E4',
    tipJar: '0xFde5101e748824488D458D41DB59a33C6C46907c',
    treasury: '0x0f0fA89471259433b6955827226f19999D93c568',
    governors: [
      '0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA',
      '0x0f0fA89471259433b6955827226f19999D93c568',
    ],
    guardians: [
      '0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA',
      '0x0f0fA89471259433b6955827226f19999D93c568',
    ],
    superKeeper: '0x0f0fA89471259433b6955827226f19999D93c568',
    whitelistManagers: ['0xDDc68f9dE415ba2fE2FD84bc62Be2d2CFF1098dA'],
    fleets: [
      {
        key: 'extDemo_USDC_base',
        label: 'ExtDemo USDC #1',
        fleetCommander: '0xd40Ac82b840AF6fbb5B3BE41eC820b5ff1199dF1',
        bufferArk: '0xE67cB1112d0AAc376EC01807F2EA551b981232E4',
        arks: ['0xC64D773717843D3dd4f71286ceD490073586Db6e'],
        roundsVaultInput: '0xcA50F64f2693b6DB0ef676cf14Dce52C183bc178',
        roundsVaultOutput: '0xB379b432b7819B3b3c4E0b7e6bE3A3f780815e82',
      },
      {
        key: 'extDemo_2_USDC_base',
        label: 'ExtDemo USDC #2',
        fleetCommander: '0xB5A07af4302fA0D2bBb389b4481055eD3F576B73',
        bufferArk: '0xcC1a3b8b61745307C0BafDc2e3132dC5D4270F06',
        arks: ['0x50CbB1759370ae82a9B8488c7D3e91Fe11A4A5B0'],
        roundsVaultInput: '0xa5BB66ED32EA16B282b0bBf827b325C564C05Cd1',
        roundsVaultOutput: '0x39B9dd2440Fc4ff138643E3a86A486487F3cfc22',
      },
    ],
  },
]

export function getInstitutionBySlug(slug: string): Institution | undefined {
  return INSTITUTIONS.find((i) => i.slug === slug)
}

export function findInstitutionByFleet(
  fleetAddress: string,
): { institution: Institution; fleet: InstitutionFleet } | undefined {
  const fa = fleetAddress.toLowerCase()
  for (const institution of INSTITUTIONS) {
    const fleet = institution.fleets.find((f) => f.fleetCommander.toLowerCase() === fa)
    if (fleet) return { institution, fleet }
  }
  return undefined
}

export function findFleetByRoundsVault(roundsVaultAddress: string):
  | {
      institution: Institution
      fleet: InstitutionFleet
      flavor: 'input' | 'output'
    }
  | undefined {
  const ra = roundsVaultAddress.toLowerCase()
  for (const institution of INSTITUTIONS) {
    for (const fleet of institution.fleets) {
      if (fleet.roundsVaultInput?.toLowerCase() === ra) {
        return { institution, fleet, flavor: 'input' }
      }
      if (fleet.roundsVaultOutput?.toLowerCase() === ra) {
        return { institution, fleet, flavor: 'output' }
      }
    }
  }
  return undefined
}
