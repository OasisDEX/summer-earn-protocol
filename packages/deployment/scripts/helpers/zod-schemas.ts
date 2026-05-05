import { Address } from 'viem'
import { z } from 'zod'

import { ArkType } from '../../types/base-types'

export const FLEET_SCHEMA_VERSION = 2

export const AddressSchema = z
  .string()
  .regex(/^0x[a-fA-F0-9]{40}$/) as unknown as z.ZodType<Address, z.ZodTypeDef, string>

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
        daoTipJar: AddressObj.optional(),
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
  roundsVaultInput: AddressSchema.optional(),
  roundsVaultOutput: AddressSchema.optional(),
})

export const InstitutionNetworkSchema = z
  .object({
    deployedContracts: InstitutionNetworkDeployedContractsSchema.optional(),
    fleets: z.record(z.string(), InstitutionFleetEntrySchema).optional(),
    treasury: AddressSchema.optional(),
    governor: z.array(AddressSchema).optional(),
    guardian: z.array(AddressSchema).optional(),
    superKeeper: AddressSchema.optional(),
    whitelistManagers: z.array(AddressSchema).optional(),
  })
  .partial()

export const InstitutionGovernanceSchema = z.object({
  treasury: AddressSchema,
  governor: z.array(AddressSchema),
  guardian: z.array(AddressSchema),
  superKeeper: AddressSchema,
  whitelistManagers: z.array(AddressSchema),
})

export const InstitutionIndexSchema = z.record(z.string(), InstitutionNetworkSchema)

export type InstitutionNetwork = z.infer<typeof InstitutionNetworkSchema>
export type InstitutionIndex = z.infer<typeof InstitutionIndexSchema>
export type InstitutionGovernance = z.infer<typeof InstitutionGovernanceSchema>
export type InstitutionFleetEntry = z.infer<typeof InstitutionFleetEntrySchema>

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

export const FleetDetailsSchema = z.object({
  name: z.string().min(1),
  chainId: z.number().int().positive(),
  asset: AddressSchema,
  assetSymbol: z.string().min(1),
  type: z.enum(['protocol', 'dao']),
})

export const VaultNameSchema = z.string().refine(
  (name) => {
    const parts = name.split('_')
    return parts.length >= 1 && parts[0].length > 0
  },
  {
    message: "Vault name must contain at least one non-empty protocol prefix (e.g., 'Aera')",
  },
)

export const BaseArkParamsSchema = z.object({
  asset: z.string().min(1),
  protocol: z.string().min(1),
  vaultName: z.string().optional(),
  fundName: z.string().optional(),
  rewardToken: z.string().optional(),
  depositCap: z.string().optional(),
  maxRebalanceOutflow: z.string().optional(),
  maxRebalanceInflow: z.string().optional(),
  maxDepositPercentageOfTVL: z.string().optional(),
  targetChainId: z.string().optional(),
  fleetName: z.string().optional(),
  vaultToken: z.string().optional(),
  arkType: z.number().optional(),
  sweepSlippage: z.string().optional(),
  version: z.number().optional(),
})

export const CrossChainArkParamsSchema = BaseArkParamsSchema.extend({
  targetChainId: z.string().min(1),
  protocol: z.string().min(1),
  version: z.number(),
})

export const ERC4626ArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
})

export const PendleLPArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
})

export const PendlePTArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
})

export const MorphoArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
})

export const SiloArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
})

export const AeraArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
})

export const WisdomTreeArkParamsSchema = BaseArkParamsSchema.extend({
  fundName: z.string().min(1),
  sweepSlippage: z.string().optional(),
})

export const SkyRewardsArkParamsSchema = BaseArkParamsSchema.extend({
  rewardToken: z.string().optional(),
})

export const ArmArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
})

export const SiUSDArkParamsSchema = BaseArkParamsSchema.extend({})

export const AaveV3ArkParamsSchema = BaseArkParamsSchema.extend({})

export const SparkArkParamsSchema = BaseArkParamsSchema.extend({})

export const CompoundV3ArkParamsSchema = BaseArkParamsSchema.extend({})

export const SkyUsdsArkParamsSchema = BaseArkParamsSchema.extend({})

export const SkyUsdsPsm3ArkParamsSchema = BaseArkParamsSchema.extend({})

export const MoonwellArkParamsSchema = BaseArkParamsSchema.extend({})

export const SyrupArkParamsSchema = BaseArkParamsSchema.extend({})

export const OriginETHArkParamsSchema = BaseArkParamsSchema.extend({})

export const FluidLiteArkParamsSchema = BaseArkParamsSchema.extend({})

export const FluidFTokenArkParamsSchema = BaseArkParamsSchema.extend({})

export const StargateV2ArkParamsSchema = BaseArkParamsSchema.extend({})

export const HyperlendArkParamsSchema = BaseArkParamsSchema.extend({})

export const HypurrArkParamsSchema = BaseArkParamsSchema.extend({})

export const MapleInstitutionalArkParamsSchema = BaseArkParamsSchema.extend({})

export const UpshiftArkParamsSchema = BaseArkParamsSchema.extend({})

export const OriginUSDArkParamsSchema = BaseArkParamsSchema.extend({})

export const PsmLiteERC4626ArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
  vaultToken: z.string().min(1),
})

export const Psm3ERC4626ArkParamsSchema = BaseArkParamsSchema.extend({
  vaultName: z.string().min(1),
  vaultToken: z.string().min(1),
})

export type ArkConfigParams = z.infer<typeof BaseArkParamsSchema>

const ArkConfigSchemaDiscriminated = z.discriminatedUnion('type', [
  z.object({
    type: z.literal(ArkType.AaveV3Ark),
    params: AaveV3ArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SparkArk),
    params: SparkArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.CompoundV3Ark),
    params: CompoundV3ArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.CrossChainArk),
    params: CrossChainArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.ERC4626Ark),
    params: ERC4626ArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SkyUsdsArk),
    params: SkyUsdsArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SkyUsdsPsm3Ark),
    params: SkyUsdsPsm3ArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.PendleLPArk),
    params: PendleLPArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.PendlePTArk),
    params: PendlePTArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.PendlePtOracleArk),
    params: PendleLPArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.MoonwellArk),
    params: MoonwellArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SyrupArk),
    params: SyrupArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SkyRewardsArk),
    params: SkyRewardsArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.MorphoArk),
    params: MorphoArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.MorphoVaultArk),
    params: MorphoArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.MorphoV2VaultArk),
    params: MorphoArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SiloArk),
    params: SiloArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SiloArkV2),
    params: SiloArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SiloManagedVaultArk),
    params: SiloArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.OriginETHArk),
    params: OriginETHArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.ArmArk),
    params: ArmArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.FluidLiteArk),
    params: FluidLiteArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.AeraArk),
    params: AeraArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.StargateV2PoolArk),
    params: StargateV2ArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.SiUSDArk),
    params: SiUSDArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.FluidFTokenArk),
    params: FluidFTokenArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.PsmLiteERC4626Ark),
    params: PsmLiteERC4626ArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.Psm3ERC4626Ark),
    params: Psm3ERC4626ArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.HyperlendArk),
    params: HyperlendArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.HypurrArk),
    params: HypurrArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.WisdomTreeArk),
    params: WisdomTreeArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.MapleInstitutionalArk),
    params: MapleInstitutionalArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.UpshiftArk),
    params: UpshiftArkParamsSchema,
  }),
  z.object({
    type: z.literal(ArkType.OriginUSDArk),
    params: OriginUSDArkParamsSchema,
  }),
])

export const ArkConfigSchema = ArkConfigSchemaDiscriminated
export type ArkConfig = z.infer<typeof ArkConfigSchema>

export const FleetConfigFileSchema = z.object({
  schemaVersion: z.literal(FLEET_SCHEMA_VERSION),
  fleetName: z.string().min(1),
  isBummer: z.boolean().optional(),
  symbol: z.string().min(1),
  assetSymbol: z.string().min(1),
  initialMinimumBufferBalance: z.string().min(1),
  initialRebalanceCooldown: z.string().min(1),
  depositCap: z.string().min(1),
  initialTipRate: z.string().min(1),
  network: z.string().min(1),
  details: FleetDetailsSchema,
  arks: z.array(ArkConfigSchema),
  curator: AddressSchema,
  keeper: AddressSchema,
  operatorType: z.enum(['admiralsQuarters', 'roundsVaults']),
  rewardTokens: z.array(AddressSchema).optional(),
  rewardAmounts: z.array(z.string()).optional(),
  rewardsDuration: z.number().optional(),
  bridgeAmount: z.string(),
  roundsVaultInput: AddressSchema.optional(),
  roundsVaultOutput: AddressSchema.optional(),
  discourseURL: z.string().optional(),
  sipNumber: z.string().optional(),
})

export const FleetConfigSchema = FleetConfigFileSchema

export const FleetDeploymentFileSchema = z.object({
  schemaVersion: z.literal(FLEET_SCHEMA_VERSION),
  fleetName: z.string().min(1),
  isBummer: z.boolean().optional(),
  fleetSymbol: z.string().min(1),
  assetSymbol: z.string().min(1),
  fleetAddress: AddressSchema,
  bufferArkAddress: AddressSchema,
  network: z.string().min(1),
  arks: z.array(AddressSchema),
  initialMinimumBufferBalance: z.string().optional(),
  initialRebalanceCooldown: z.string().optional(),
  depositCap: z.string().optional(),
  initialTipRate: z.string().optional(),
  details: FleetDetailsSchema,
  roundsVaultInput: AddressSchema.optional(),
  roundsVaultOutput: AddressSchema.optional(),
})

export const FleetDeploymentSchema = FleetDeploymentFileSchema

export type FleetDetails = z.infer<typeof FleetDetailsSchema>
export type ArkDetails = z.infer<typeof ArkDeploymentDetailsSchema>
export type FleetConfig = z.infer<typeof FleetConfigFileSchema>
export type FleetDeployment = z.infer<typeof FleetDeploymentFileSchema>
export type OperatorType = z.infer<typeof FleetConfigSchema.shape.operatorType>

export const DeployedBridgeSchema = z.object({
  bridgeRouter: z.object({ address: AddressSchema }),
  bridgeQueue: z.object({ address: AddressSchema }),
  crossChainRegistry: z.object({ address: AddressSchema }),
  adapters: z
    .object({
      layerZero: z.object({ address: AddressSchema }).optional(),
      stargate: z.object({ address: AddressSchema }).optional(),
    })
    .optional(),
})

export const GovContractsSchema = z.object({
  summerGovernor: AddressObj,
  summerToken: AddressObj,
  timelock: AddressObj,
  protocolAccessManager: AddressObj,
  rewardsRedeemer: AddressObj,
  summerVestingFactory: AddressObj.optional(),
  summerVestingFactoryV2: AddressObj.optional(),
  timelockGuardFactory: AddressObj.optional(),
})

export const GovV2ContractsSchema = z.object({
  summerGovernor: AddressObj,
  summerGovernanceToken: AddressObj,
  timelock: AddressObj,
  protocolAccessManager: AddressObj,
  summerStaking: AddressObj,
  summerVestingWalletsEscrow: AddressObj,
})

export const CoreContractsSchema = z.object({
  tipJar: AddressObj,
  raft: AddressObj,
  configurationManager: AddressObj,
  harborCommand: AddressObj,
  admiralsQuarters: AddressObj,
  fleetCommanderRewardsManagerFactory: AddressObj,
  institutionalVaultRegistry: AddressObj.optional(),
  daoTipJar: AddressObj.optional(),
})

export const BridgeAdaptersSchema = z.object({
  layerZero: AddressObj.optional(),
  stargate: AddressObj.optional(),
})

export const BridgeSchema = z.object({
  bridgeRouter: AddressObj,
  bridgeQueue: AddressObj,
  crossChainRegistry: AddressObj.optional(),
  adapters: BridgeAdaptersSchema.optional(),
})

export const ProtocolSpecificAaveV3Schema = z.object({
  pool: z.string(),
  rewards: z.string(),
})

export const ProtocolSpecificSparkSchema = z.object({
  pool: z.string(),
  rewards: z.string(),
})

export const ProtocolSpecificMorphoSchema = z.object({
  blue: z.string(),
  urdFactory: z.string(),
  vaults: z.record(z.string(), z.record(z.string(), z.string())),
  markets: z.record(z.string(), z.record(z.string(), z.string())),
})

export const ProtocolSpecificCompoundV3Schema = z.object({
  pools: z.record(z.string(), z.object({ cToken: z.string() })),
  rewards: z.string(),
})

export const ProtocolSpecificSkySchema = z.object({
  psmLite: z.record(z.string(), AddressSchema).optional(),
  psm3: z.record(z.string(), AddressSchema).optional(),
  staking: z.object({
    sky: AddressSchema,
  }),
})

export const ProtocolSpecificMoonwellSchema = z.object({
  pools: z.record(z.string(), z.object({ mToken: AddressSchema })),
  comptroller: AddressSchema,
})

export const ProtocolSpecificSyrupSchema = z.object({
  pools: z.record(
    z.string(),
    z.object({
      syrup: AddressSchema,
      router: AddressSchema,
    }),
  ),
})

export const ProtocolSpecificSiloSchema = z.object({
  pools: z.record(z.string(), z.record(z.string(), AddressSchema)),
  vaults: z.record(z.string(), z.record(z.string(), AddressSchema)),
})

export const ProtocolSpecificFluidSchema = z.object({
  lite: z.record(
    z.string(),
    z.object({
      wrapper: AddressSchema,
      vault: AddressSchema,
      withdrawalQueue: AddressSchema,
    }),
  ),
  fToken: z.record(
    z.string(),
    z.object({
      fToken: AddressSchema,
      merkleDistributor: AddressSchema,
    }),
  ),
})

export const ProtocolSpecificOriginETHSchema = z.object({
  originETH: AddressSchema,
  arm: AddressSchema,
  arms: z.record(z.string(), z.record(z.string(), AddressSchema)),
})

export const ProtocolSpecificAeraSchema = z.object({
  vaults: z.record(z.string(), z.record(z.string(), z.object({ provisioner: AddressSchema }))),
})

export const ProtocolSpecificStargateSchema = z.object({
  staking: AddressSchema,
  pools: z.record(z.string(), AddressSchema),
})

export const ProtocolSpecificInfinifiSchema = z.object({
  gateway: AddressSchema,
  siUSD: AddressSchema,
})

export const ProtocolSpecificPendleSchema = z.object({
  router: AddressSchema,
  'lp-oracle': AddressSchema,
  markets: z.record(
    z.string(),
    z.object({
      marketAddresses: z.record(z.string(), AddressSchema),
      swapInTokens: z.array(
        z.object({
          token: z.string(),
          oracle: AddressSchema,
        }),
      ),
    }),
  ),
})

export const ProtocolSpecificHyperlendSchema = z.object({
  pool: AddressSchema,
  rewards: AddressSchema,
})

export const ProtocolSpecificHypurrSchema = z.object({
  pool: AddressSchema,
  rewards: AddressSchema,
})

export const ProtocolSpecificSchema = z.object({
  aaveV3: ProtocolSpecificAaveV3Schema.optional(),
  spark: ProtocolSpecificSparkSchema.optional(),
  morpho: ProtocolSpecificMorphoSchema.optional(),
  compoundV3: ProtocolSpecificCompoundV3Schema.optional(),
  erc4626: z.record(z.string(), z.record(z.string(), z.string())).optional(),
  sky: ProtocolSpecificSkySchema.optional(),
  moonwell: ProtocolSpecificMoonwellSchema.optional(),
  syrup: ProtocolSpecificSyrupSchema.optional(),
  silo: ProtocolSpecificSiloSchema.optional(),
  fluid: ProtocolSpecificFluidSchema.optional(),
  originETH: ProtocolSpecificOriginETHSchema.optional(),
  aera: ProtocolSpecificAeraSchema.optional(),
  stargate: ProtocolSpecificStargateSchema.optional(),
  infinifi: ProtocolSpecificInfinifiSchema.optional(),
  pendle: ProtocolSpecificPendleSchema.optional(),
  hyperlend: ProtocolSpecificHyperlendSchema.optional(),
  hypurr: ProtocolSpecificHypurrSchema.optional(),
  bridge: BridgeSchema.optional(),
})

export const BaseConfigSchema = z.object({
  deployedContracts: z.object({
    gov: GovContractsSchema,
    govV2: GovV2ContractsSchema,
    buyAndBurn: z.object({ buyAndBurn: AddressObj }),
    core: CoreContractsSchema,
    bridge: BridgeSchema.optional(),
  }),
  tokens: z.record(z.string(), AddressSchema),
  common: z.object({
    chainId: z.string(),
    initialSupply: z.string(),
    swapProvider: AddressSchema,
    tipRate: z.string(),
    foundation: AddressSchema.optional(),
    merklDistributor: AddressSchema.optional(),
    layerZero: z.object({
      lzEndpoint: AddressSchema,
      eID: z.string(),
      lzExecutor: z.string(),
      sendUln302: z.string(),
      receiveUln302: z.string(),
      blockedMessageLib: z.string(),
      lzDeadDVN: z.string(),
      dvns: z.record(
        z.string(),
        z.object({
          lzLabs: z.string(),
          secondDvn: z.string(),
        }),
      ).optional(),
    }),
  }),
  protocolSpecific: ProtocolSpecificSchema,
  bridge: BridgeSchema.optional(),
})

export const ConfigSchema = z.record(z.string(), BaseConfigSchema)

export const CrossChainDestinationProtocolSchema = z.object({
  protocol: z.string(),
  poolAddress: AddressSchema.optional(),
  stakingRewardsAddress: AddressSchema.optional(),
  marketId: z.string().optional(),
})

export const CrossChainDestinationSchema = z.object({
  chainId: z.number(),
  protocols: z.array(CrossChainDestinationProtocolSchema),
})

export const CrossChainConfigSchema = z.object({
  destinations: z.array(CrossChainDestinationSchema),
})
export type DeployedBridge = z.infer<typeof DeployedBridgeSchema>
export type BaseConfig = z.infer<typeof BaseConfigSchema>
export type Config = z.infer<typeof ConfigSchema>
export type CrossChainConfig = z.infer<typeof CrossChainConfigSchema>
