import { z } from 'zod'

/** Schema version for fleet config/deployment JSON files. Bump when breaking schema changes are made. */
export const FLEET_SCHEMA_VERSION = 2

export const AddressSchema = z.string().regex(/^0x[a-fA-F0-9]{40}$/)

/** Address schema that rejects the zero address */
export const NonZeroAddressSchema = AddressSchema.refine(
  (addr) => addr.toLowerCase() !== '0x0000000000000000000000000000000000000000',
  { message: 'Address cannot be zero' },
)

const AddressObj = z.object({ address: AddressSchema })

export const InstitutionNetworkDeployedContractsSchema = z
  .object({
    gov: z
      .object({
        protocolAccessManager: AddressObj.optional(),
      })
      .partial()
      .optional(),
    core: z
      .object({
        tipJar: AddressObj.optional(),
        configurationManager: AddressObj.optional(),
        harborCommand: AddressObj.optional(),
        admiralsQuarters: AddressObj.optional(),
        raft: AddressObj.optional(),
      })
      .partial()
      .optional(),
  })
  .partial()

export const InstitutionFleetEntrySchema = z.object({
  fleetCommander: AddressSchema,
  bufferArk: AddressSchema,
  arks: z.array(AddressSchema),
})

export const InstitutionNetworkSchema = z
  .object({
    deployedContracts: InstitutionNetworkDeployedContractsSchema.optional(),
    fleets: z.record(z.string(), InstitutionFleetEntrySchema).optional(),
    treasury: AddressSchema.optional(),
    governor: z.array(AddressSchema).optional(),
    guardian: z.array(AddressSchema).optional(),
  })
  .partial()

export const InstitutionGovernanceSchema = z.object({
  treasury: AddressSchema,
  governor: z.array(AddressSchema),
  guardian: z.array(AddressSchema),
})

export const InstitutionIndexSchema = z.record(z.string(), InstitutionNetworkSchema)

export type InstitutionNetwork = z.infer<typeof InstitutionNetworkSchema>
export type InstitutionIndex = z.infer<typeof InstitutionIndexSchema>
export type InstitutionGovernance = z.infer<typeof InstitutionGovernanceSchema>
export type InstitutionFleetEntry = z.infer<typeof InstitutionFleetEntrySchema>

/** Ark type string literal union - must match ArkType enum in config-types */
const ArkTypeLiteral = z.enum([
  'AaveV3Ark',
  'SparkArk',
  'CompoundV3Ark',
  'CrossChainArk',
  'ERC4626Ark',
  'MorphoArk',
  'MorphoVaultArk',
  'PendleLPArk',
  'PendlePTArk',
  'PendlePtOracleArk',
  'SkyUsdsArk',
  'SkyUsdsPsm3Ark',
  'MoonwellArk',
  'SyrupArk',
  'SkyRewardsArk',
  'SiloArk',
  'SiloArkV2',
  'SiloManagedVaultArk',
  'OriginETHArk',
  'ArmArk',
  'FluidLiteArk',
  'AeraArk',
  'StargateV2PoolArk',
  'SiUSDArk',
  'FluidFTokenArk',
  'PsmLiteERC4626Ark',
  'Psm3ERC4626Ark',
  'HyperlendArk',
  'HypurrArk',
])

/**
 * User input params for arks in fleet config (arks[].params).
 * Uses symbols/names (e.g. asset: "USDC", protocol: "aaveV3").
 * .passthrough() allows ark-type-specific fields (maxDepositPercentageOfTVL, vaultToken, etc.).
 */
const ArkParamsSchema = z
  .object({
    asset: z.string().min(1),
    protocol: z.string().min(1),
    vaultName: z.string().optional(),
    depositCap: z.string().optional(),
    maxRebalanceOutflow: z.string().optional(),
    maxRebalanceInflow: z.string().optional(),
    maxDepositPercentageOfTVL: z.string().optional(),
    vaultToken: z.string().optional(),
    targetChainId: z.string().optional(),
    fleetName: z.string().optional(),
  })
  .passthrough()

export const ArkConfigSchema = z.object({
  type: ArkTypeLiteral,
  params: ArkParamsSchema,
})

/**
 * Resolved ark details after deployment - contract-facing structure.
 * Uses addresses (asset, pool, etc.) and chainId. Built by each ark deploy script,
 * validated here, then JSON.stringified into the contract.
 */
export const ArkDeploymentDetailsSchema = z.object({
  protocol: z.string().min(1),
  pool: AddressSchema,
  chainId: z.number().int().positive(),
  type: z.string().optional(),
  asset: AddressSchema.optional(),
  marketAsset: AddressSchema.optional(),
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

/** Schema for fleet details - always an object in canonical format */
export const FleetDetailsSchema = z.object({
  name: z.string().min(1),
  chainId: z.number().int().positive(),
  asset: AddressSchema,
  assetSymbol: z.string().min(1),
  type: z.enum(['protocol', 'dao']),
})

export type FleetDetails = z.infer<typeof FleetDetailsSchema>
/** Resolved ark details for contract storage. Use ArkDeploymentDetailsSchema for validation. */
export type ArkDetails = z.infer<typeof ArkDeploymentDetailsSchema>
export type ArkConfig = z.infer<typeof ArkConfigSchema>

/**
 * Canonical fleet config file schema (v2).
 * Config files live in config/fleets/ with names like {network}-{asset}-{id}.json or *.bummer.json.
 * fleetName + network must be unique; deployment output uses {sanitizedFleetName}_{network}_deployment.json.
 */
export const FleetConfigFileSchema = z.object({
  schemaVersion: z.literal(FLEET_SCHEMA_VERSION),
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
  arks: z.array(ArkConfigSchema),
  curator: AddressSchema.optional(),
  keeper: AddressSchema.optional(),
  rewardTokens: z.array(AddressSchema).optional(),
  rewardAmounts: z.array(z.string()).optional(),
  rewardsDuration: z.number().optional(),
  bridgeAmount: z.string().optional(),
  sipNumber: z.string().optional(),
  discourseURL: z.string().optional(),
})

/**
 * Canonical fleet deployment file schema (v2).
 * Deployment files live in deployments/fleets/ as {sanitizedFleetName}_{network}_deployment.json.
 * fleetSymbol = config.symbol; named explicitly for deployment context.
 */
export const FleetDeploymentFileSchema = z.object({
  schemaVersion: z.literal(FLEET_SCHEMA_VERSION),
  fleetName: z.string().min(1),
  isBummer: z.boolean(),
  fleetSymbol: z.string().min(1),
  assetSymbol: z.string().min(1),
  fleetAddress: AddressSchema,
  bufferArkAddress: AddressSchema,
  network: z.string().min(1),
  arks: z.array(AddressSchema).default([]),
  initialMinimumBufferBalance: z.string().optional(),
  initialRebalanceCooldown: z.string().optional(),
  depositCap: z.string().optional(),
  initialTipRate: z.string().optional(),
  details: FleetDetailsSchema,
})

/** Schema for vault name validation - ensures protocol_name format */
export const VaultNameSchema = z.string().refine(
  (name) => {
    const parts = name.split('_')
    return parts.length >= 1 && parts[0].length > 0
  },
  {
    message: "Vault name must contain at least one non-empty protocol prefix (e.g., 'Aera')",
  },
)
