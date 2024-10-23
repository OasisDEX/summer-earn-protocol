import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { keccak256, toBytes } from 'viem'
import { ADDRESS_ZERO } from '../../scripts/common/constants'

enum DecayType {
  Linear,
  Exponential,
}

const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000'
const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))

export const GovModule = buildModule('GovModule', (m) => {
  const deployer = m.getAccount(0)
  const lzEndpoint = m.getParameter('lzEndpoint')

  const summerTokenParams = {
    name: 'SummerToken',
    symbol: 'SUMMER',
    lzEndpoint: lzEndpoint,
    governor: deployer,
  }
  // Deploy SummerToken contract
  const summerToken = m.contract('SummerToken', [summerTokenParams])

  /*
   * Deploy TimelockController contract
   * - `minDelay`: initial minimum delay in seconds for operations
   * - `proposers`: accounts to be granted proposer and canceller roles
   * - `executors`: accounts to be granted executor role
   * - `admin`: optional account to be granted admin role; disable with zero address
   */
  const MIN_DELAY = 86400
  const TEMP_MIN_DELAY_DURING_TESTING = MIN_DELAY / 24
  const timelock = m.contract('TimelockController', [
    TEMP_MIN_DELAY_DURING_TESTING,
    [deployer],
    [ADDRESS_ZERO],
    deployer,
  ])

  /*
   * @dev Struct for the governor parameters
   * @param token The token contract address
   * @param timelock The timelock controller contract address
   * @param votingDelay The voting delay in seconds
   * @param votingPeriod The voting period in seconds
   * @param proposalThreshold The proposal threshold in tokens
   * @param quorumFraction The quorum fraction in tokens
   * @param initialWhitelistGuardian The initial whitelist guardian address
   * @param initialDecayFreeWindow The initial decay free window in seconds
   * @param initialDecayRate The initial decay rate
   * @param initialDecayFunction The initial decay function
   * @param endpoint The LayerZero endpoint address
   * @param proposalChainId The proposal chain ID
   */
  const summerGovernorDeployParams = {
    token: summerToken,
    timelock: timelock,
    votingDelay: 1,
    votingPeriod: 50400,
    proposalThreshold: 10000n * 10n ** 18n,
    quorumFraction: 4,
    initialWhitelistGuardian: deployer,
    initialDecayFreeWindow: 30n * 24n * 60n * 60n,
    initialDecayRate: 3.1709792e9,
    initialDecayFunction: DecayType.Linear,
    endpoint: lzEndpoint,
    proposalChainId: 8453,
  }

  // Deploy SummerGovernor contract
  const summerGovernor = m.contract('SummerGovernor', [summerGovernorDeployParams])

  m.call(timelock, 'grantRole', [PROPOSER_ROLE, summerGovernor.value])
  m.call(timelock, 'grantRole', [CANCELLER_ROLE, summerGovernor.value])
  m.call(timelock, 'grantRole', [EXECUTOR_ROLE, summerGovernor.value])

  // Grant DEFAULT_ADMIN_ROLE back to the TimelockController itself
  m.call(timelock, 'grantRole', [DEFAULT_ADMIN_ROLE, timelock.value])

  // Revoke DEFAULT_ADMIN_ROLE from the deployer
  m.call(timelock, 'revokeRole', [DEFAULT_ADMIN_ROLE, deployer])

  return {
    summerGovernor,
    summerToken,
    timelock,
  }
})

export type GovContracts = {
  summerGovernor: { address: string }
  summerToken: { address: string }
  timelock: { address: string }
}
