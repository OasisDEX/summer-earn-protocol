import hre from 'hardhat'
import kleur from 'kleur'
import { Address as ViemAddress, getAddress } from 'viem'

import { InstitutionGovernance } from './zod-schemas'

const dedupeAddresses = (addrs: string[]): ViemAddress[] =>
  Array.from(new Set(addrs.map((a) => a.toLowerCase()))).map((a) => getAddress(a))

/**
 * Proposer sets for the three institution timelocks, derived from governance. The curator set falls
 * back to the governor set when no curators are configured (mirrors the deploy script). The treasury
 * set defaults to the governor set. These are the accounts that MUST be able to schedule operations
 * once the deployer has renounced.
 */
export function computeTimelockProposers(governance: InstitutionGovernance): {
  governorProposers: ViemAddress[]
  curatorProposers: ViemAddress[]
  treasuryProposers: ViemAddress[]
} {
  const governorProposers = dedupeAddresses(governance.governor as string[])
  const curatorProposers = dedupeAddresses(
    (governance.curators?.length ?? 0) > 0
      ? (governance.curators as string[])
      : (governance.governor as string[]),
  )
  // Treasury timelock proposers default to the governor set
  const treasuryProposers = dedupeAddresses(governance.governor as string[])
  return { governorProposers, curatorProposers, treasuryProposers }
}

/**
 * Verifies a recorded RwaTimelock address is safe to grant authority to / hand governance over to,
 * BEFORE any (often irreversible) role change. Verifying the delay alone is not enough — a stale or
 * mistyped address could be an EOA, the wrong contract, or a real timelock whose proposer set does
 * not match the intended operators (which would brick governance once the deployer renounces). This
 * checks all three and THROWS (fail-fast) on any mismatch:
 *   - the address has contract code (not an EOA / dead address),
 *   - it reports the configured `minDelay` (right contract, no config drift),
 *   - every expected proposer holds PROPOSER_ROLE (the intended operators can actually schedule).
 */
export async function assertTimelockUsable(
  label: string,
  address: ViemAddress,
  expectedDelaySeconds: number,
  expectedProposers: ViemAddress[],
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  publicClient: any,
): Promise<void> {
  const code = (await publicClient.getBytecode({ address })) as `0x${string}` | undefined
  if (!code || code === '0x') {
    throw new Error(
      `${label} ${address} has no contract code — refusing. Verify the address recorded in the institution index.`,
    )
  }

  const tl = await hre.viem.getContractAt('RwaTimelock' as string, address)

  const onChainDelay = (await tl.read.getMinDelay()) as bigint
  if (onChainDelay !== BigInt(expectedDelaySeconds)) {
    throw new Error(
      `${label} ${address} reports minDelay ${onChainDelay}s but config expects ${expectedDelaySeconds}s ` +
        `— refusing (wrong address recorded, or the config has drifted).`,
    )
  }

  const proposerRole = (await tl.read.PROPOSER_ROLE()) as `0x${string}`
  const missing: string[] = []
  for (const proposer of expectedProposers) {
    const hasRole = (await tl.read.hasRole([proposerRole, proposer])) as boolean
    if (!hasRole) missing.push(proposer)
  }
  if (missing.length > 0) {
    const list = missing.map((m) => `  - ${m}`).join('\n')
    throw new Error(
      `${label} ${address} is missing PROPOSER_ROLE for ${missing.length} expected proposer(s):\n${list}\n` +
        `Refusing — these accounts could not schedule operations, so once the deployer renounces ` +
        `GOVERNOR_ROLE the timelock would permanently brick governance. Verify the timelock's ` +
        `proposer set matches the configured governors/curators.`,
    )
  }

  console.log(
    kleur.gray(
      `[ok] ${label} ${address} verified (minDelay=${onChainDelay}s, ${expectedProposers.length} proposer(s) hold PROPOSER_ROLE)`,
    ),
  )
}
