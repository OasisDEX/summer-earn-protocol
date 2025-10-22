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
