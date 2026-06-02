// 100% expressed in the contract's Percentage type (18 decimals): 100 * 1e18.
const PERCENTAGE_100 = 100n * 10n ** 18n

/**
 * Projects how many asset units a recipient would receive from a `shake`, given
 * the fleet's pending shakeable amount and the recipient's raw allocation
 * (Percentage, 18 decimals). Mirrors `withdrawnAssets.applyPercentage(allocation)`
 * in TipJar._shake.
 */
export function projectedPayout(pendingAssets: bigint, allocationRaw: bigint): bigint {
  if (pendingAssets <= 0n || allocationRaw <= 0n) return 0n
  return (pendingAssets * allocationRaw) / PERCENTAGE_100
}
