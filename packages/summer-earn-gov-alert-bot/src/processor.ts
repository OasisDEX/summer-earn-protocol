import { PublicClient, Log, decodeEventLog } from 'viem'
import { SupportedNetworks, decodeCalldata, addresToContractName } from './services/validation'
import { getGovernorAddresses, getTimelockAddress } from './config'
import { TelegramNotifier } from './telegram'
import { GOVERNOR_EVENTS, TIMELOCK_EVENTS } from './abis'

const KNOWN_ROLES: Record<string, string> = {
  '0x0000000000000000000000000000000000000000000000000000000000000000': 'DEFAULT_ADMIN_ROLE',
  '0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5': 'TIMELOCK_ADMIN_ROLE',
  '0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1': 'PROPOSER_ROLE',
  '0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63': 'EXECUTOR_ROLE',
  '0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783': 'CANCELLER_ROLE',
}

export class EventProcessor {
  constructor(
    private notifier: TelegramNotifier,
    private network: SupportedNetworks,
    private client: PublicClient,
    private targetChatId?: string | number,
  ) {}

  private decodeRoleHash(role: string): string {
    return KNOWN_ROLES[role.toLowerCase()] || `Unknown Role (${role.slice(0, 10)}...)`
  }

  async processGovernorLogs(logs: Log[]) {
    for (const log of logs) {
      try {
        const decoded = decodeEventLog({
          abi: GOVERNOR_EVENTS,
          data: log.data,
          topics: (log as any).topics,
          strict: false,
        }) as any

        if (!decoded) continue

        const governorName = addresToContractName(log.address!, this.network)

        if (decoded.eventName === 'ProposalCreated') {
          const { proposer, targets, calldatas, proposalId } = decoded.args as any
          const actions = targets.map((target: string, i: number) => ({
            target,
            targetName: addresToContractName(target, this.network),
            calldata: calldatas[i],
            decodedCall: decodeCalldata(calldatas[i], target, this.network),
          }))

          await this.notifier.notifyProposalCreated(
            this.network,
            governorName,
            proposer,
            log.transactionHash!,
            actions,
            this.targetChatId,
          )
        } else if (decoded.eventName === 'RoleGranted' || decoded.eventName === 'RoleRevoked') {
          const { role, account, sender } = decoded.args as any
          await this.notifier.notifyRoleChange(
            this.network,
            decoded.eventName === 'RoleGranted' ? 'Granted' : 'Revoked',
            this.decodeRoleHash(role),
            account,
            sender,
            log.transactionHash!,
            this.targetChatId,
          )
        } else {
          await this.notifier.notifyGenericEvent(
            this.network,
            `Governor: ${decoded.eventName}`,
            `Proposal ID: ${decoded.args.proposalId}\nGovernor: ${governorName}`,
            log.transactionHash!,
            this.targetChatId,
          )
        }
      } catch (error) {
        // Silently skip signature missing errors to avoid noise from auxiliary events
        if ((error as any).name !== 'AbiEventSignatureNotFoundError') {
          console.error('Error processing governor log:', error)
        }
      }
    }
  }

  async processTimelockLogs(logs: Log[]) {
    const governorAddresses = getGovernorAddresses(this.network).map((a) => a.toLowerCase())
    const timelockAddress = getTimelockAddress(this.network)

    for (const log of logs) {
      try {
        const decoded = decodeEventLog({
          abi: TIMELOCK_EVENTS,
          data: log.data,
          topics: (log as any).topics,
          strict: false,
        }) as any

        if (!decoded) continue

        if (decoded.eventName === 'CallScheduled') {
          const tx = await this.client.getTransaction({ hash: log.transactionHash! })
          const sender = tx.from.toLowerCase()

          const isGovernor = governorAddresses.includes(sender)

          if (!isGovernor) {
            await this.notifier.notifySecurityBypass(
              this.network,
              timelockAddress || log.address!,
              sender,
              (decoded.args as any).target,
              log.transactionHash!,
              this.targetChatId,
            )
          } else {
            // Normal scheduling via Governor
            await this.notifier.notifyGenericEvent(
              this.network,
              'Timelock: Call Scheduled',
              `Target: ${addresToContractName((decoded.args as any).target, this.network)}`,
              log.transactionHash!,
              this.targetChatId,
            )
          }
        } else if (decoded.eventName === 'RoleGranted' || decoded.eventName === 'RoleRevoked') {
          const { role, account, sender } = decoded.args as any
          await this.notifier.notifyRoleChange(
            this.network,
            decoded.eventName === 'RoleGranted' ? 'Granted' : 'Revoked',
            this.decodeRoleHash(role),
            account,
            sender,
            log.transactionHash!,
            this.targetChatId,
          )
        } else {
          await this.notifier.notifyGenericEvent(
            this.network,
            `Timelock: ${decoded.eventName}`,
            `Operation ID: ${decoded.args.id}`,
            log.transactionHash!,
            this.targetChatId,
          )
        }
      } catch (error) {
        // Silently skip signature missing errors to avoid noise from auxiliary events
        if ((error as any).name !== 'AbiEventSignatureNotFoundError') {
          console.error('Error processing timelock log:', error)
        }
      }
    }
  }
}
