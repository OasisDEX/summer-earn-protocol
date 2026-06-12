import { z } from 'zod'

export const AddressSchema = z.string().regex(/^0x[a-fA-F0-9]{40}$/)

const AddressObj = z.object({ address: AddressSchema })

// Strict: an unknown key here would otherwise be silently stripped on the next index write —
// i.e. a recorded deployment address could vanish. New contracts MUST be added to this schema.
export const InstitutionNetworkDeployedContractsSchema = z
  .object({
    gov: z
      .object({
        protocolAccessManager: AddressObj.optional(),
        // The three RwaTimelock instances deployed per institution. `governorTimelock` is the
        // sole GOVERNOR_ROLE holder; `curatorTimelock` holds CURATOR_ROLE on each fleet;
        // `treasuryTimelock` acts as the institution treasury address.
        governorTimelock: AddressObj.optional(),
        curatorTimelock: AddressObj.optional(),
        treasuryTimelock: AddressObj.optional(),
      })
      .partial()
      .strict()
      .optional(),
    core: z
      .object({
        tipJar: AddressObj.optional(),
        daoTipJar: AddressObj.optional(),
        configurationManager: AddressObj.optional(),
        harborCommand: AddressObj.optional(),
        admiralsQuarters: AddressObj.optional(),
        raft: AddressObj.optional(),
      })
      .partial()
      .strict()
      .optional(),
  })
  .partial()
  .strict()

export const InstitutionFleetEntrySchema = z
  .object({
    fleetCommander: AddressSchema,
    bufferArk: AddressSchema,
    arks: z.array(AddressSchema),
    roundsVaultInput: AddressSchema.optional(),
    roundsVaultOutput: AddressSchema.optional(),
  })
  .strict()

/**
 * Per-institution timelock configuration.
 *
 * Three RwaTimelock instances are ALWAYS deployed per institution: a Governor timelock (sole
 * GOVERNOR_ROLE holder), a Curator timelock (CURATOR_ROLE on each fleet), and a Treasury timelock
 * (used as the institution's treasury address). This block does not toggle whether the timelocks
 * exist — it only sets each one's delay (in seconds):
 *
 *   - `0`   → that timelock executes immediately (schedule + execute can happen in the same block),
 *             so it imposes no waiting period while keeping the schedule→execute flow uniform.
 *   - `> 0` → that timelock enforces a mandatory wait of N seconds between schedule and execute.
 *
 * This block is MANDATORY for every configured network entry — there is no implicit default.
 */
// Upper sanity bound on a timelock delay, in seconds. Catches unit confusion (e.g. a value entered
// in milliseconds) and fat-fingered magnitudes that would brick governance for years — the timelock
// is self-administered, so an over-large delay cannot be shortened, only waited out. 365 days is far
// longer than any realistic governance review window while still rejecting absurd values.
export const MAX_TIMELOCK_DELAY_SECONDS = 365 * 24 * 60 * 60 // 31_536_000

export const TimelockConfigSchema = z
  .object({
    governorDelay: z.number().int().nonnegative().max(MAX_TIMELOCK_DELAY_SECONDS),
    curatorDelay: z.number().int().nonnegative().max(MAX_TIMELOCK_DELAY_SECONDS),
    treasuryDelay: z.number().int().nonnegative().max(MAX_TIMELOCK_DELAY_SECONDS),
  })
  .strict()

export type TimelockConfig = z.infer<typeof TimelockConfigSchema>

// Strict (rejects unknown keys): every write re-parses through this schema, so a non-strict
// object would silently strip unrecognized fields from the file instead of failing loudly.
export const InstitutionNetworkSchema = z
  .object({
    deployedContracts: InstitutionNetworkDeployedContractsSchema.optional(),
    fleets: z.record(z.string(), InstitutionFleetEntrySchema).optional(),
    // Per-network governance fields. NOTE: there is intentionally no `treasury` field — the
    // institution treasury is ALWAYS the deployed TreasuryTimelock (wired into ConfigurationManager
    // at deploy time), never a configured address.
    governor: z.array(AddressSchema).optional(),
    // Proposers of the curator timelock — the institution's curators. Kept separate from
    // `governor` so the two roles can be segregated (different signer sets). When omitted, the
    // curator timelock falls back to the governor set.
    curators: z.array(AddressSchema).optional(),
    guardian: z.array(AddressSchema).optional(),
    superKeeper: AddressSchema.optional(),
    whitelistManagers: z.array(AddressSchema).optional(),
    // Per-network timelock delays. MANDATORY: all three RwaTimelock instances are always deployed, so
    // every configured network entry MUST declare its delays. Use { governorDelay: 0, curatorDelay: 0,
    // treasuryDelay: 0 } to EXPLICITLY opt out of any delay ("none" mode) — there is no silent default.
    timelock: TimelockConfigSchema,
  })
  .strict()

// Governance fields structure (used for validating per-network governance). The institution
// treasury is not configurable: ConfigurationManager.treasury is set to the TreasuryTimelock
// deployed alongside the institution (see ignition/modules/institution-whitelist.ts), so no
// `treasury` field exists here.
export const InstitutionGovernanceSchema = z.object({
  governor: z.array(AddressSchema),
  // Optional curator proposer set; defaults to empty (callers fall back to `governor`). Optional
  // so existing institution configs that predate this field still validate.
  curators: z.array(AddressSchema).optional().default([]),
  guardian: z.array(AddressSchema),
  superKeeper: AddressSchema,
  whitelistManagers: z.array(AddressSchema),
})

// Top-level: record of network name -> schema
export const InstitutionIndexSchema = z.record(z.string(), InstitutionNetworkSchema)

export type InstitutionNetwork = z.infer<typeof InstitutionNetworkSchema>
export type InstitutionIndex = z.infer<typeof InstitutionIndexSchema>
export type InstitutionGovernance = z.infer<typeof InstitutionGovernanceSchema>
export type InstitutionFleetEntry = z.infer<typeof InstitutionFleetEntrySchema>

// Schema for ark details validation - ensures minimal required fields for offchain processing
export const ArkDetailsSchema = z.object({
  protocol: z.string().min(1),
  pool: AddressSchema,
  chainId: z.number().int().positive(),
  // Optional fields that may be present in different ark types
  type: z.string().optional(),
  asset: AddressSchema.optional(),
  marketAsset: AddressSchema.optional(),
  // Additional protocol-specific fields
  gateway: AddressSchema.optional(),
  vaultId: z.string().optional(),
  marketId: z.string().optional(),
  marketName: z.string().optional(),
  siloId: z.string().optional(),
  fToken: AddressSchema.optional(),
  syrupAddress: AddressSchema.optional(),
  armAddress: AddressSchema.optional(),
  poolAddress: AddressSchema.optional(),
  vault: AddressSchema.optional(),
  stakingRewardsAddress: AddressSchema.optional(),
  originETHAddress: AddressSchema.optional(),
  sparkPool: AddressSchema.optional(),
  mToken: AddressSchema.optional(),
  psm3Address: AddressSchema.optional(),
  psmLiteAddress: AddressSchema.optional(),
  stargatePool: AddressSchema.optional(),
  compoundV3Pool: AddressSchema.optional(),
  aaveV3Pool: AddressSchema.optional(),
})

// Schema for fleet details validation - ensures required fields for fleet metadata
export const FleetDetailsSchema = z.object({
  name: z.string().min(1),
  chainId: z.number().int().positive(),
  asset: AddressSchema,
  assetSymbol: z.string().min(1),
  type: z.enum(['protocol', 'dao']),
})

export const FleetConfigSchema = z.object({
  fleetName: z.string().min(1),
  isBummer: z.boolean(),
  symbol: z.string().min(1),
  assetSymbol: z.string().min(1),
  initialMinimumBufferBalance: z.string().min(1),
  initialRebalanceCooldown: z.string().min(1),
  depositCap: z.string().min(1),
  initialTipRate: z.string().min(1),
  network: z.string().min(1),
  details: FleetDetailsSchema,
  arks: z.array(z.any()),
  curator: AddressSchema,
  keeper: AddressSchema,
  operatorType: z.enum(['admiralsQuarters', 'roundsVaults']),
  rewardTokens: z.array(AddressSchema).optional(),
  rewardAmounts: z.array(z.string()).optional(),
  rewardsDuration: z.number().optional(),
  bridgeAmount: z.string().optional(),
  sipNumber: z.string().optional(),
  discourseURL: z.string().optional(),
})

export const FleetDeploymentSchema = z.object({
  fleetName: z.string().min(1),
  isBummer: z.boolean(),
  fleetSymbol: z.string().min(1),
  assetSymbol: z.string().min(1),
  fleetAddress: AddressSchema,
  bufferArkAddress: AddressSchema,
  network: z.string().min(1),
  // Allow optional during initial save (filled later by addArkToFleet)
  arks: z.array(AddressSchema).optional(),
  initialMinimumBufferBalance: z.string().optional(),
  initialRebalanceCooldown: z.string().optional(),
  depositCap: z.string().optional(),
  initialTipRate: z.string().optional(),
  details: FleetDetailsSchema,
})

export type FleetDetails = z.infer<typeof FleetDetailsSchema>
export type ArkDetails = z.infer<typeof ArkDetailsSchema>

// Schema for vault name validation - ensures protocol_name format
export const VaultNameSchema = z.string().refine(
  (name) => {
    const parts = name.split('_')
    return parts.length >= 1 && parts[0].length > 0
  },
  {
    message: "Vault name must contain at least one non-empty protocol prefix (e.g., 'Aera')",
  },
)
