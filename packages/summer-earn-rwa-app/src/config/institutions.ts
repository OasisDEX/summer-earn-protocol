// Static directory of institutions + their fleets + rounds-vaults, keyed by
// app environment (production and staging are different contract deployments).
// Mirrors packages/deployment/config/institutions/<name>/index.test.json
// (and the production index.json once that exists). Addresses are inlined to
// avoid coupling Next bundling to the deployment workspace package; refresh
// these by hand when the registry is redeployed.

import { base, mainnet } from 'wagmi/chains'

import type { AppEnvironment } from '@/config/appEnvironment'
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
  /** Governor timelock — sole GOVERNOR_ROLE holder. Present once the institution is deployed
   *  with the timelock flow. A delay of 0 means it executes immediately. */
  governorTimelock?: `0x${string}`
  /** Curator timelock — holds CURATOR_ROLE on each fleet. */
  curatorTimelock?: `0x${string}`
  /** Treasury timelock — controls the treasury address when present. */
  treasuryTimelock?: `0x${string}`
  /** Timelock delays in seconds (0 = immediate execution). */
  timelock?: { governorDelay: number; curatorDelay: number }
  configurationManager: `0x${string}`
  harborCommand: `0x${string}`
  admiralsQuarters: `0x${string}`
  raft: `0x${string}`
  tipJar: `0x${string}`
  /** Off-chain role assignments encoded in the deployment JSON. */
  treasury: `0x${string}`
  governors: `0x${string}`[]
  /** Curator timelock proposers — may differ from governors. */
  curators?: `0x${string}`[]
  guardians: `0x${string}`[]
  superKeeper: `0x${string}`
  whitelistManagers: `0x${string}`[]
  fleets: InstitutionFleet[]
}

const STAGING_INSTITUTIONS: Institution[] = [
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
  {
    // Ignition deployment `staging_InstitutionWhitelist_Orthodox` (Ethereum
    // mainnet). Roles/bufferArk/treasury read back from chain at block
    // ~25300784; delays via getMinDelay() on each timelock.
    slug: 'orthodox',
    displayName: 'Orthodox',
    chainId: String(mainnet.id) as ChainId,
    protocolAccessManager: '0xc098248Ec73DF55c0fb3f9bEfcF62eE4C45097D1',
    governorTimelock: '0x3C8be759Ff177390BF038104a5A1ED7C498f562A',
    curatorTimelock: '0xd02aC5CAdf26E2E9d6326a51Db5Fe150e9198419',
    treasuryTimelock: '0x20aF9545eBb320c80C5736880bAA7a244a75868f',
    timelock: { governorDelay: 0, curatorDelay: 0 },
    configurationManager: '0x9d0eBe533D1BEaE6AF0b86AdA16926f9D69e4257',
    harborCommand: '0x4357889A5A88005133b46e4174feA13266Fb4a7D',
    admiralsQuarters: '0xc5c96cA7607eCe902092F4080B844AA0Bb5C1Ff4',
    raft: '0x0f77bb8d65e5238E63e496D94049E4e4C953F704',
    tipJar: '0xCDa1586aDA05330e46075Ed8c58B9f6E8DCf7A7f',
    treasury: '0x20aF9545eBb320c80C5736880bAA7a244a75868f',
    governors: ['0x0f0fA89471259433b6955827226f19999D93c568'],
    guardians: ['0x85f9b7408aFE6CeB5E46223451f5d4b832B522dc'],
    superKeeper: '0x85f9b7408aFE6CeB5E46223451f5d4b832B522dc',
    whitelistManagers: [
      '0x0f0fA89471259433b6955827226f19999D93c568',
      '0x85f9b7408aFE6CeB5E46223451f5d4b832B522dc',
    ],
    fleets: [
      {
        key: 'Orthodox_Summerfi_Strategic_Allocation',
        label: 'Orthodox Summerfi Strategic Allocation',
        fleetCommander: '0x35aE5392cc355686606658d18dff9b9109390E13',
        bufferArk: '0x051c51593EBFfd1797aAcBdB3FABFe6839EA7E40',
        arks: ['0x5E09B3f6502b089ca19abB7025a3434F157a15E0'],
        roundsVaultInput: '0x50D9275348C4C5BB2Bf928473118A63ee95dc467',
        roundsVaultOutput: '0x7bCFE1371BE235528196Fa0d7e639DB97dDB0Fe6',
      },
    ],
  },
]

const PRODUCTION_INSTITUTIONS: Institution[] = [
  {
    // Ignition deployment `InstitutionWhitelist_Avantgarde` (Ethereum mainnet,
    // registry 0xb2f4Ce82e974Ad9A6391B4eB3D1266054a0aD9a4). Mirrors
    // packages/deployment/config/institutions/Avantgarde/index.json.
    slug: 'avantgarde',
    displayName: 'Avantgarde',
    chainId: String(mainnet.id) as ChainId,
    protocolAccessManager: '0x26cE19153DB119BDF2bCF299503f7D419d4a6d4f',
    governorTimelock: '0x25c538Af61e9D3B5AFC7862f7ec9FFbf96323873',
    curatorTimelock: '0xadd75388AcE5b57321b2090F5481f2a8F2a681Dd',
    treasuryTimelock: '0x420E610eeFF3a611997bd290572e1E1EF21683CD',
    timelock: { governorDelay: 0, curatorDelay: 0 },
    configurationManager: '0x81C4910248351360Db75B3650Fd7527b08DbBcb1',
    harborCommand: '0x330Fb246Edb7d961ED232B5a68558A68Df513206',
    admiralsQuarters: '0x2F6220A53a6C08254146646C4b2807647a79127a',
    raft: '0x97E0D1282162E2d7ABd50FF2E08b769DB20E5E69',
    tipJar: '0x0799385e9d77Fe0A7F459976ccd97f96cBAC547B',
    treasury: '0x420E610eeFF3a611997bd290572e1E1EF21683CD',
    governors: ['0x85f9b7408afE6CEb5E46223451f5d4b832B522dc'],
    curators: ['0x85f9b7408afE6CEb5E46223451f5d4b832B522dc'],
    guardians: ['0x85f9b7408afE6CEb5E46223451f5d4b832B522dc'],
    superKeeper: '0x85f9b7408afE6CEb5E46223451f5d4b832B522dc',
    whitelistManagers: ['0x85f9b7408afE6CEb5E46223451f5d4b832B522dc'],
    fleets: [
      {
        key: 'Avantgarde_Summerfi_Strategic_RWA_Allocation',
        label: 'Avantgarde Summerfi Strategic RWA Allocation',
        fleetCommander: '0xbafDA316a19fc4A824e14A1EF86f2c57055Df9ec',
        bufferArk: '0x05903f725285ea778f1DbDad0C8d11876A979Ef5',
        arks: [],
        roundsVaultInput: '0x9322249c4BD4C06f8da62A096ff25bB4c0255a80',
        roundsVaultOutput: '0x8b916d68fDdED0B446EB2FA6D72322D3F1c77BeD',
      },
    ],
  },
]

export const INSTITUTIONS_BY_ENV: Record<AppEnvironment, Institution[]> = {
  production: PRODUCTION_INSTITUTIONS,
  staging: STAGING_INSTITUTIONS,
}

export function getInstitutions(env: AppEnvironment): Institution[] {
  return INSTITUTIONS_BY_ENV[env]
}

export function getInstitutionBySlug(env: AppEnvironment, slug: string): Institution | undefined {
  return getInstitutions(env).find((i) => i.slug === slug)
}

export function findInstitutionByFleet(
  env: AppEnvironment,
  fleetAddress: string,
): { institution: Institution; fleet: InstitutionFleet } | undefined {
  const fa = fleetAddress.toLowerCase()
  for (const institution of getInstitutions(env)) {
    const fleet = institution.fleets.find((f) => f.fleetCommander.toLowerCase() === fa)
    if (fleet) return { institution, fleet }
  }
  return undefined
}

export function findFleetByRoundsVault(
  env: AppEnvironment,
  roundsVaultAddress: string,
):
  | {
      institution: Institution
      fleet: InstitutionFleet
      flavor: 'input' | 'output'
    }
  | undefined {
  const ra = roundsVaultAddress.toLowerCase()
  for (const institution of getInstitutions(env)) {
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
