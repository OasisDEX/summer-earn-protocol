import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const HUB_CHAIN_ID = 8453n // BASE

/**
 * @title Governance Module Deployment Script
 * @notice This module handles the deployment and initialization of the governance system
 *
 * @dev Deployment and initialization sequence:
 * 0. Use existing timelock and accessManager
 * 1. Deploy SummerGovernor V2
 */
export const GovModuleV2 = buildModule('GovModuleV2', (m) => {
  const deployer = m.getAccount(0)
  const timelock = m.getParameter('timelock')
  const accessManager = m.getParameter('accessManager')
  const stakedSummerToken = m.getParameter('stakedSummerToken')
  const lzEndpoint = m.getParameter('lzEndpoint')
  const votingDelay = m.getParameter('votingDelay', 60n)
  const votingPeriod = m.getParameter('votingPeriod', 600n)
  const proposalThreshold = m.getParameter('proposalThreshold', 10000n * 10n ** 18n)
  const quorumFraction = m.getParameter('quorumFraction', 4n)

  /**
   * @dev Step 1: Deploy SummerGovernor
   * This contract manages the governance process
   */
  const summerGovernorDeployParams = {
    token: stakedSummerToken,
    timelock: timelock,
    accessManager: accessManager,
    votingDelay: votingDelay,
    votingPeriod: votingPeriod,
    proposalThreshold: proposalThreshold,
    quorumFraction: quorumFraction,
    endpoint: lzEndpoint,
    hubChainId: HUB_CHAIN_ID,
    initialOwner: deployer,
  }

  const summerGovernor = m.contract('SummerGovernorV2', [summerGovernorDeployParams])

  return {
    summerGovernor,
  }
})

export type GovContractsV2 = {
  summerGovernor: { address: string }
}
