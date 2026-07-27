export const harborCommandAbiHuman = [
  'function getActiveFleetCommanders() view returns (address[])',
] as const

export const fleetCommanderAbiHuman = [
  'function getActiveArks() view returns (address[])',
  'function bufferArk() view returns (address)',
  'function asset() view returns (address)',
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function totalAssets() view returns (uint256)',
  'function withdrawableTotalAssets() view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function getConfig() view returns ((address bufferArk, uint256 minimumBufferBalance, uint256 depositCap, uint256 maxRebalanceOperations, address stakingRewardsManager))',
  'function balanceOf(address) view returns (uint256)',
  'function convertToAssets(uint256) view returns (uint256)',
] as const

export const arkAbiHuman = [
  'function totalAssets() view returns (uint256)',
  'function withdrawableTotalAssets() view returns (uint256)',
  'function name() view returns (string)',
  'function depositCap() view returns (uint256)',
  'function maxDepositPercentageOfTVL() view returns (uint256)',
  'function maxRebalanceInflow() view returns (uint256)',
  'function maxRebalanceOutflow() view returns (uint256)',
  'function details() view returns (string)',
] as const

export const arkWithWithdrawalRequestAbiHuman = [
  'function withdrawalRequestId() view returns (uint256)',
  'function assetsInWithdrawalQueue() view returns (uint256)',
  'function isWithdrawalClaimRequired() view returns (bool)',
] as const

export const wisdomTreeArkAbiHuman = [
  'function pendingDepositAssets() view returns (uint256)',
  'function sharesToAssets(uint256) view returns (uint256)',
] as const

export const erc20AbiHuman = [
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function balanceOf(address) view returns (uint256)',
  'function allowance(address,address) view returns (uint256)',
] as const

export const tipJarAbiHuman = [
  'function getAllTipStreams() view returns ((address recipient, uint256 allocation, uint256 lockedUntilEpoch)[])',
  'function getTotalAllocation() view returns (uint256)',
  'function paused() view returns (bool)',
] as const
