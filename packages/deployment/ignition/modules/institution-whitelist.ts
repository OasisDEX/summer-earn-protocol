import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

/**
 * Institution-scoped whitelist deployment module.
 * Deploys a minimal governance access layer and core contracts for an institution:
 * - ProtocolAccessManagerWhitelist
 * - GovernorTimelock + CuratorTimelock (two RwaTimelock instances)
 * - ConfigurationManager
 * - TipJar
 * - HarborCommand
 * - Raft (kept for ConfigurationManager wiring compatibility)
 * - AdmiralsQuarters
 *
 * Both timelocks are always deployed. `governorDelay` / `curatorDelay` (seconds) set each one's
 * minimum delay; 0 means immediate execution. `governorTimelockProposers` and
 * `curatorTimelockProposers` are the (separate) sets of accounts allowed to schedule operations on
 * each timelock — segregating the governor and curator signer sets. Executors are left open
 * (anyone may execute a ready operation) and there is no separate admin, so the timelocks are
 * fully self-administered.
 */
export function createInstitutionWhitelistModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const deployer = m.getAccount(0)

    // External parameters from global chain config
    const swapProvider = m.getParameter('swapProvider')
    const weth = m.getParameter('weth')
    const treasury = m.getParameter('treasury')

    // Timelock parameters
    const governorDelay = m.getParameter('governorDelay')
    const curatorDelay = m.getParameter('curatorDelay')
    const governorTimelockProposers = m.getParameter('governorTimelockProposers')
    const curatorTimelockProposers = m.getParameter('curatorTimelockProposers')
    const timelockExecutors = [ZERO_ADDRESS] // open execution
    const timelockAdmin = ZERO_ADDRESS // self-administered

    // Deploy institution-scoped access manager
    const protocolAccessManager = m.contract('ProtocolAccessManagerV2', [deployer])

    // Two timelocks: one gates GOVERNOR_ROLE actions, one gates per-fleet CURATOR_ROLE actions.
    // Each gets its own proposer set so governor and curator authority can be segregated.
    const governorTimelock = m.contract(
      'RwaTimelock',
      [governorDelay, governorTimelockProposers, timelockExecutors, timelockAdmin],
      { id: 'GovernorTimelock' },
    )
    const curatorTimelock = m.contract(
      'RwaTimelock',
      [curatorDelay, curatorTimelockProposers, timelockExecutors, timelockAdmin],
      { id: 'CuratorTimelock' },
    )

    // Core infra and components
    const dutchAuctionLibrary = m.contract('DutchAuctionLibrary', [])

    const configurationManager = m.contract('ConfigurationManagerWhitelist', [
      protocolAccessManager,
    ])
    const tipJar = m.contract('TipJar', [protocolAccessManager, configurationManager])

    const harborCommand = m.contract('HarborCommand', [protocolAccessManager])

    const raft = m.contract('Raft', [protocolAccessManager], {
      libraries: { DutchAuctionLibrary: dutchAuctionLibrary },
    })

    // Initialize ConfigurationManager relations
    const configurationManagerParams = {
      raft: raft,
      tipJar: tipJar,
      treasury: treasury,
      harborCommand: harborCommand,
      // No dedicated factory for whitelist flow - we keep it for compability with core contracts
      fleetCommanderRewardsManagerFactory: '0x0000000000000000000000000000000000000000',
    }
    m.call(configurationManager, 'initializeConfiguration', [configurationManagerParams])

    // AdmiralsQuarters depends on configuration being set
    const admiralsQuarters = m.contract('AdmiralsQuartersWhitelist', [
      swapProvider,
      configurationManager,
      protocolAccessManager,
      weth,
    ])

    return {
      protocolAccessManager,
      governorTimelock,
      curatorTimelock,
      configurationManager,
      tipJar,
      harborCommand,
      raft,
      admiralsQuarters,
    }
  })
}
