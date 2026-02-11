import { z } from 'zod'

const addressSchema = z.string().regex(/^0x[a-fA-F0-9]{40}$/)
const networkSchema = z.enum(['base', 'arbitrum', 'mainnet'])

/** Oracle provider type (e.g. WisdomTree) */
export const OracleTypeSchema = z.enum(['WisdomTree'])
export type OracleType = z.infer<typeof OracleTypeSchema>

/** Oracle data source subtype (e.g. variableNav) */
export const OracleSubtypeSchema = z.enum(['variableNav', 'fixedNav'])
export type OracleSubtype = z.infer<typeof OracleSubtypeSchema>

/** Single oracle config for deploy input */
export const OracleConfigSchema = z.object({
  network: networkSchema,
  assetAddress: addressSchema,
  description: z.string().optional(),
  signers: z.array(addressSchema),
  threshold: z.number().int().positive(),
  type: OracleTypeSchema.default('WisdomTree'),
  subtype: OracleSubtypeSchema.default('variableNav'),
})

/** Deploy input: single config or array of configs */
export const DeploymentInputSchema = z.union([OracleConfigSchema, z.array(OracleConfigSchema)])

export type DeploymentInput = z.infer<typeof DeploymentInputSchema>

/** Single oracle entry in the deployment file */
export const OracleEntrySchema = z.object({
  ticker: z.string(),
  assetAddress: addressSchema,
  oracleAddress: addressSchema,
  type: OracleTypeSchema,
  subtype: OracleSubtypeSchema,
})

export type OracleEntry = z.infer<typeof OracleEntrySchema>

/** Per-chain deployment data */
export const ChainDeploymentSchema = z.object({
  chainId: z.number().int().positive(),
  oracleRegistry: addressSchema,
  oracles: z.array(OracleEntrySchema).default([]),
})

export type ChainDeployment = z.infer<typeof ChainDeploymentSchema>

/** Full deployment file: network key -> chain deployment */
export const DeploymentFileSchema = z.record(z.string(), ChainDeploymentSchema)

export type DeploymentFile = z.infer<typeof DeploymentFileSchema>

/** Private key schema */
export const PrivateKeySchema = z.string().regex(/^0x[a-fA-F0-9]{64}$/)
export type PrivateKey = z.infer<typeof PrivateKeySchema>
