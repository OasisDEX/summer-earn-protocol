import { z } from 'zod'

export const AddressSchema = z.string().regex(/^0x[a-fA-F0-9]{40}$/)

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
  })
  .partial()

// Top-level: record of network name -> schema
export const InstitutionIndexSchema = z.record(z.string(), InstitutionNetworkSchema)

export type InstitutionIndex = z.infer<typeof InstitutionIndexSchema>
export type InstitutionFleetEntry = z.infer<typeof InstitutionFleetEntrySchema>

export const FleetConfigSchema = z.object({
  fleetName: z.string().min(1),
  symbol: z.string().min(1),
  assetSymbol: z.string().min(1),
  initialMinimumBufferBalance: z.union([z.string(), z.number(), z.bigint()]),
  initialRebalanceCooldown: z.union([z.string(), z.number()]),
  depositCap: z.union([z.string(), z.number(), z.bigint()]),
  initialTipRate: z.union([z.string(), z.number(), z.bigint()]),
  network: z.string().min(1),
  details: z.unknown(),
  arks: z.array(z.any()).optional(),
})

export const FleetDeploymentSchema = z.object({
  fleetName: z.string().min(1),
  isBummer: z.boolean().optional(),
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
})

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

export type ArkDetails = z.infer<typeof ArkDetailsSchema>

// Schema for vault name validation - ensures protocol_name format
export const VaultNameSchema = z.string().refine(
  (name) => {
    const parts = name.split('_')
    return parts.length >= 2 && parts[0].length > 0 && parts[parts.length - 1].length > 0
  },
  {
    message:
      "Vault name must contain at least one underscore with a non-empty protocol prefix (e.g., 'Aera_VaultName')",
  },
)
