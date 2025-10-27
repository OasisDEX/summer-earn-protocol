import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { FleetCommanderEnlisted } from '../../generated/HarborCommand/HarborCommand'
import { Vault, YieldAggregator } from '../../generated/schema'
import { addresses } from '../common/addressProvider'
import { BigDecimalConstants, BigIntConstants } from '../common/constants'
import {
  getOrCreateArksDailySnapshots,
  getOrCreateArksHourlySnapshots,
  getOrCreatePosition,
  getOrCreatePositionDailySnapshot,
  getOrCreatePositionHourlySnapshot,
  getOrCreatePositionRewards,
  getOrCreatePositionWeeklySnapshot,
  getOrCreateToken,
  getOrCreateVault,
  getOrCreateVaultWeeklySnapshots,
  getOrCreateVaultsDailySnapshots,
  getOrCreateVaultsHourlySnapshots,
  getOrCreateYieldAggregator,
} from '../common/initializers'
import {
  decodeValues,
  encodeFunctionCalldata,
  makeMulticall,
  prepareMulicallCall,
} from '../common/multicall'
import { formatAmount } from '../common/utils'
import { getArkDetails } from '../utils/ark'
import { getVaultDetails } from '../utils/vault'
import {
  getDailyTimestamp,
  getHourlyTimestamp,
  getWeeklyOffsetTimestamp,
  handleVaultRate,
} from '../utils/vaultRateHandlers'
import { updateArk } from './entities/ark'
import { updateVault } from './entities/vault'
import { updateAccountStakingRewards } from './governanceRewardsManager'

export function handleFleetCommanderEnlisted(event: FleetCommanderEnlisted): void {
  getOrCreateVault(event.params.fleetCommander, event.block)
}

function updateArkData(vault: Vault, arkAddress: Address, block: ethereum.Block): void {
  const arkDetails = getArkDetails(vault, arkAddress, block)
  updateArk(arkDetails, block, true)
}

export function updateVaultData(vault: Vault, block: ethereum.Block): Vault {
  const vaultDetails = getVaultDetails(vault, block)
  return updateVault(vaultDetails, block, true)
}

// Snapshot management functions
function updateArkSnapshots(
  vault: Vault,
  arkAddress: Address,
  block: ethereum.Block,
  shouldUpdateDaily: boolean,
): void {
  getOrCreateArksHourlySnapshots(vault, arkAddress, block)
  if (shouldUpdateDaily) {
    getOrCreateArksDailySnapshots(vault, arkAddress, block)
  }
}

function updateVaultSnapshots(
  vault: Vault,
  block: ethereum.Block,
  shouldUpdateDaily: boolean,
  shouldUpdateWeekly: boolean,
): void {
  handleVaultRate(block, vault.id)
  getOrCreateVaultsHourlySnapshots(vault, block)
  if (shouldUpdateDaily) {
    getOrCreateVaultsDailySnapshots(vault, block)
  }
  if (shouldUpdateWeekly) {
    getOrCreateVaultWeeklySnapshots(vault, block)
  }
}

// Main update orchestration functions
function processHourlyVaultUpdate(
  vaultAddress: Address,
  block: ethereum.Block,
  protocolLastDailyUpdateTimestamp: BigInt | null,
  protocolLastHourlyUpdateTimestamp: BigInt | null,
  protocolLastWeeklyUpdateTimestamp: BigInt | null,
): void {
  const dayPassed = hasDayPassed(protocolLastDailyUpdateTimestamp, block.timestamp)
  const hourPassed = hasHourPassed(protocolLastHourlyUpdateTimestamp, block.timestamp)
  const weekPassed = hasWeekPassed(protocolLastWeeklyUpdateTimestamp, block.timestamp)
  if (hourPassed) {
    let vault = getOrCreateVault(vaultAddress, block)
    const updatedVault = updateVaultData(vault, block)
    updateVaultSnapshots(updatedVault, block, dayPassed, weekPassed)

    // reload vault to get latest data
    vault = updatedVault
    if (!vault || !vault.id) {
      log.warning('Invalid vault at address ' + vaultAddress.toHexString(), [])
      return
    }

    const arks = vault.arksArray
    if (arks && arks.length > 0) {
      for (let j = 0; j < arks.length; j++) {
        if (!arks[j]) {
          log.warning('Empty ark ID at index ' + j.toString(), [])
          continue
        }

        if (!arks[j].startsWith('0x') || arks[j].length != 42) {
          log.warning('Invalid ark address format at index ' + j.toString(), [])
          continue
        }

        const arkAddress = Address.fromString(arks[j])
        updateArkData(vault, arkAddress, block)
        updateArkSnapshots(vault, arkAddress, block, dayPassed)
      }
    }

    const positions = vault.positions
    if (positions && positions.length > 0) {
      for (let k = 0; k < positions.length; k++) {
        const positionId = positions[k]
        if (!positionId) {
          log.warning('Empty position ID at index ' + k.toString(), [])
          continue
        }
        getOrCreatePositionHourlySnapshot(positionId, vault, block)
        if (dayPassed) {
          getOrCreatePositionDailySnapshot(positionId, vault, block)
        }
        if (weekPassed) {
          getOrCreatePositionWeeklySnapshot(positionId, vault, block)
        }
      }
    }
    const positionsToUpdate: string[] = []
    const ownersOfPositions: string[] = []
    for (let i = 0; i < positions.length; i++) {
      const position = getOrCreatePosition(positions[i], block)
      if (position.stakedInputTokenBalanceNormalizedInUSD.gt(BigDecimalConstants.ONE)) {
        positionsToUpdate.push(positions[i])
        ownersOfPositions.push(position.account)
      }
    }
    log.error('[harborCommand] - block {} time taken for positionsToUpdate:', [
      block.number.toString(),
    ])
    if (positionsToUpdate.length > 0 && vault.rewardTokens.length > 0) {
      const rewardTokenAddress = Address.fromString(vault.rewardTokens[0])
      const rewardToken = getOrCreateToken(rewardTokenAddress)

      let calls = new Array<ethereum.Tuple>(positionsToUpdate.length)
      for (let i = 0; i < positionsToUpdate.length; i++) {
        calls[i] = prepareMulicallCall(
          Address.fromBytes(vault.stakingRewardsManager),
          encodeFunctionCalldata(
            'earned(address,address)',
            ['address', 'address'],
            [ownersOfPositions[i], rewardTokenAddress.toHexString()],
          ),
        )
      }
      const multicallResult = makeMulticall(calls)
      log.error('[harborCommand] - block {} time taken for multicall', [block.number.toString()])
      const multiCallResponseData = multicallResult.value.value1
      for (let i = 0; i < multiCallResponseData.length; i++) {
        const position = getOrCreatePosition(positionsToUpdate[i], block)
        const results = decodeValues('uint256', multiCallResponseData[i])
        const claimableNormalized = formatAmount(
          BigInt.fromString(results[0]),
          BigInt.fromI32(rewardToken.decimals),
        )
        const positionRewards = getOrCreatePositionRewards(positionsToUpdate[i], rewardToken, block)

        positionRewards.claimable = BigInt.fromString(results[0])
        positionRewards.claimableNormalized = claimableNormalized
        positionRewards.save()

        // ------------------------------------------------------------
        // will be deprecated in the future
        if (rewardTokenAddress.equals(addresses.SUMMER_TOKEN)) {
          position.claimableSummerToken = positionRewards.claimable
          position.claimableSummerTokenNormalized = positionRewards.claimableNormalized
          position.save()
        }
        // ------------------------------------------------------------}
      }
    }
    log.error('[harborCommand] - time taken for positionsToUpdate:', [block.number.toString()])
  }
}

export function handleInterval(block: ethereum.Block): void {
  // ENABLE ONLY for separate subgraph deployment
  // temporary solution to track self managed vault deployment on base for institutional demo app
  // if (dataSource.network() == 'base') {
  //   const usdcDemoFleetOnBase = Address.fromString('0x29f13a877F3d1A14AC0B15B07536D4423b35E198')
  //   getOrCreateVault(usdcDemoFleetOnBase, block)
  // }

  if (!block || !block.timestamp) {
    log.warning('Invalid block or timestamp in handleInterval', [])
    return
  }

  let protocol = getOrCreateYieldAggregator(block.timestamp)

  if (!protocol || !protocol.vaultsArray) {
    log.warning('Protocol or vaultsArray is null', [])
    return
  }

  const hourPassed = hasHourPassed(protocol.lastHourlyUpdateTimestamp, block.timestamp)
  if (hourPassed) {
    updateAccountStakingRewards(block.number)
  }

  const vaults = protocol.vaultsArray

  for (let i = 0; i < vaults.length; i++) {
    if (!vaults[i]) {
      log.warning('Empty vault ID at index ' + i.toString(), [])
      continue
    }

    if (!vaults[i].startsWith('0x') || vaults[i].length != 42) {
      log.warning('Invalid vault address format at index ' + i.toString(), [])
      continue
    }

    const vaultAddress = Address.fromString(vaults[i])

    processHourlyVaultUpdate(
      vaultAddress,
      block,
      protocol.lastDailyUpdateTimestamp,
      protocol.lastHourlyUpdateTimestamp,
      protocol.lastWeeklyUpdateTimestamp,
    )
  }

  updateProtocolTimestamps(protocol, block)
  protocol.save()
}

function updateProtocolTimestamps(protocol: YieldAggregator, block: ethereum.Block): void {
  if (hasHourPassed(protocol.lastHourlyUpdateTimestamp, block.timestamp)) {
    const firstSecondOfThisHour = getHourlyTimestamp(block.timestamp)
    protocol.lastHourlyUpdateTimestamp = firstSecondOfThisHour

    if (hasDayPassed(protocol.lastDailyUpdateTimestamp, block.timestamp)) {
      const dayTimestamp = getDailyTimestamp(firstSecondOfThisHour)
      protocol.lastDailyUpdateTimestamp = dayTimestamp
    }

    if (hasWeekPassed(protocol.lastWeeklyUpdateTimestamp, block.timestamp)) {
      const weekTimestamp = getWeeklyOffsetTimestamp(firstSecondOfThisHour)
      protocol.lastWeeklyUpdateTimestamp = weekTimestamp
    }

    protocol.save()
  }
}

function hasDayPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }
  const currentDayTimestamp = getDailyTimestamp(currentTimestamp)
  const previousDayTimestamp = lastUpdateTimestamp
  return !currentDayTimestamp.equals(previousDayTimestamp)
}

function hasHourPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }
  const currentHourTimestamp = getHourlyTimestamp(currentTimestamp)
  const previousHourTimestamp = lastUpdateTimestamp
  return !currentHourTimestamp.equals(previousHourTimestamp)
}

function hasWeekPassed(lastUpdateTimestamp: BigInt | null, currentTimestamp: BigInt): boolean {
  if (!lastUpdateTimestamp || lastUpdateTimestamp.equals(BigIntConstants.ZERO)) {
    return true // Create initial snapshot if no previous timestamp or if it's zero
  }

  const currentWeekTimestamp = getWeeklyOffsetTimestamp(currentTimestamp)
  const previousWeekTimestamp = getWeeklyOffsetTimestamp(lastUpdateTimestamp)

  return !currentWeekTimestamp.equals(previousWeekTimestamp)
}
