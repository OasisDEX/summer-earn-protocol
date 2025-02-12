import chalk from 'chalk'
import hre from 'hardhat'
import { Address } from 'viem'

export interface FleetConfig {
  depositCap: bigint
  minimumBufferBalance: bigint
  rebalanceCooldown: number
}

export interface ArkConfig {
  depositCap: bigint
  maxDepositPercentageOfTVL: bigint
  maxRebalanceInflow: bigint
  maxRebalanceOutflow: bigint
}

export async function readFleetConfig(fleetAddress: Address): Promise<FleetConfig> {
  const fleetCommander = await hre.viem.getContractAt(
    'FleetCommander' as string,
    fleetAddress as `0x${string}`,
  )

  const config = (await fleetCommander.read.getConfig()) as FleetConfig
  const rebalanceCooldown = await fleetCommander.read.getCooldown()
  return {
    depositCap: BigInt(config.depositCap),
    minimumBufferBalance: BigInt(config.minimumBufferBalance),
    rebalanceCooldown: Number(rebalanceCooldown),
  }
}

export async function readArkConfig(arkAddress: Address): Promise<ArkConfig> {
  const ark = await hre.viem.getContractAt('Ark' as string, arkAddress as `0x${string}`)

  const [depositCap, maxDepositPercentageOfTVL, maxRebalanceInflow, maxRebalanceOutflow] =
    await Promise.all([
      ark.read.depositCap(),
      ark.read.maxDepositPercentageOfTVL(),
      ark.read.maxRebalanceInflow(),
      ark.read.maxRebalanceOutflow(),
    ])

  return {
    depositCap: BigInt(depositCap as bigint),
    maxDepositPercentageOfTVL: BigInt(maxDepositPercentageOfTVL as bigint),
    maxRebalanceInflow: BigInt(maxRebalanceInflow as bigint),
    maxRebalanceOutflow: BigInt(maxRebalanceOutflow as bigint),
  }
}

const MAX_UINT256 = BigInt(
  '115792089237316195423570985008687907853269984665640564039457584007913129639935',
)

function formatValue(value: bigint | number, unit: string): string {
  // Handle max uint
  if (typeof value === 'bigint' && value === MAX_UINT256) {
    return 'max uint (no limit)'
  }

  // Handle decimals for known assets
  if (unit.trim() === 'USDC' || unit.trim() === 'USDT') {
    if (typeof value === 'bigint') {
      const formatted = Number(value) / 1e6
      return `${value.toString()} (${formatted.toLocaleString()})`
    }
  }

  if (unit.trim() === 'WETH') {
    if (typeof value === 'bigint') {
      const formatted = Number(value) / 1e18
      return `${value.toString()} (${formatted.toLocaleString()})`
    }
  }

  // Default formatting for other values
  return value.toString()
}

export function logValueComparison(
  label: string,
  currentValue: bigint | number,
  newValue: bigint | number,
  unit: string = '',
): void {
  const hasChanged = currentValue !== newValue
  const color = hasChanged ? chalk.red : chalk.green
  const arrow = hasChanged ? '→' : '='

  const formattedCurrent = formatValue(currentValue, unit)
  const formattedNew = formatValue(newValue, unit)

  console.log(
    color(
      `${label.padEnd(30)} ${formattedCurrent}${unit} ${arrow} ${formattedNew}${unit}${
        hasChanged ? ' (updating)' : ' (unchanged)'
      }`,
    ),
  )
}

export function logPercentageComparison(
  label: string,
  currentValue: bigint,
  newValue: bigint,
  WAD: bigint,
): void {
  const hasChanged = currentValue !== newValue
  const color = hasChanged ? chalk.red : chalk.green
  const arrow = hasChanged ? '→' : '='
  const currentPercent = Number(currentValue) / Number(WAD)
  const newPercent = Number(newValue) / Number(WAD)
  console.log(
    color(
      `${label.padEnd(30)} ${currentPercent}% ${arrow} ${newPercent}%${
        hasChanged ? ' (updating)' : ' (unchanged)'
      }`,
    ),
  )
}
