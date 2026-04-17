import { Telegraf } from 'telegraf'
import { SupportedNetworks } from './services/validation'

const EXPLORER_URLS: Record<string, string> = {
  [SupportedNetworks.MAINNET]: 'https://etherscan.io/tx/',
  [SupportedNetworks.BASE]: 'https://basescan.org/tx/',
  [SupportedNetworks.ARBITRUM]: 'https://arbiscan.io/tx/',
  [SupportedNetworks.SONIC]: 'https://sonicscan.org/tx/',
}

export class TelegramNotifier {
  public bot: Telegraf
  private chatId: string

  constructor(token: string, chatId: string) {
    this.bot = new Telegraf(token)
    this.chatId = chatId
  }

  async launch() {
    await this.bot.launch()
  }

  async sendHtml(message: string, overrideChatId?: string | number) {
    try {
      await this.bot.telegram.sendMessage(overrideChatId || this.chatId, message, {
        parse_mode: 'HTML',
      })
    } catch (error) {
      console.error('Error sending Telegram message:', error)
    }
  }

  formatTxLink(network: SupportedNetworks, hash: string): string {
    const baseUrl = EXPLORER_URLS[network] || 'https://etherscan.io/tx/'
    return `<a href="${baseUrl}${hash}">View Transaction</a>`
  }

  async notifyProposalCreated(
    network: SupportedNetworks,
    governorName: string,
    proposer: string,
    txHash: string,
    actions: any[],
    overrideChatId?: string | number,
  ) {
    const actionStrings = actions
      .map((a, i) => {
        const decodedLine = a.decodedCall
          ? `Function: <code>${a.decodedCall.functionName}</code>\n   Decoded: <code>${JSON.stringify(a.decodedCall.args)}</code>`
          : `Calldata: <code>${a.calldata.slice(0, 66)}...</code>`

        return `${i + 1}. Target: <code>${a.targetName || a.target}</code>\n   ${decodedLine}`
      })
      .join('\n\n')

    const message = `🏛 <b>New Proposal Created [${network.toUpperCase()}]</b>
<b>Governor:</b> ${governorName}
<b>Proposer:</b> <code>${proposer}</code>

<b>Actions:</b>
${actionStrings}

🔗 ${this.formatTxLink(network, txHash)}`

    await this.sendHtml(message, overrideChatId)
  }

  async notifySecurityBypass(
    network: SupportedNetworks,
    timelock: string,
    sender: string,
    target: string,
    txHash: string,
    overrideChatId?: string | number,
  ) {
    const message = `🚨 <b>CRITICAL ALARM: TIMELOCK BYPASS [${network.toUpperCase()}]</b> 🚨
A transaction was scheduled directly on the Timelock without going through the Governor!

<b>Timelock:</b> <code>${timelock}</code>
<b>Malicious Sender:</b> <code>${sender}</code>
<b>Target:</b> <code>${target}</code>

🔗 ${this.formatTxLink(network, txHash)}
Investigate Immediately`

    await this.sendHtml(message, overrideChatId)
  }

  async notifyGenericEvent(
    network: SupportedNetworks,
    title: string,
    details: string,
    txHash: string,
    overrideChatId?: string | number,
  ) {
    const message = `ℹ️ <b>${title} [${network.toUpperCase()}]</b>
${details}

🔗 ${this.formatTxLink(network, txHash)}`

    await this.sendHtml(message, overrideChatId)
  }

  async notifyRoleChange(
    network: SupportedNetworks,
    action: 'Granted' | 'Revoked',
    role: string,
    account: string,
    sender: string,
    txHash: string,
    overrideChatId?: string | number,
  ) {
    const actionEmoji = action === 'Granted' ? '✅' : '🚫'
    const message = `${actionEmoji} <b>Role ${action} [${network.toUpperCase()}]</b>
<b>Role:</b> <code>${role}</code>
<b>Account:</b> <code>${account}</code>
<b>Admin/Sender:</b> <code>${sender}</code>

🔗 ${this.formatTxLink(network, txHash)}`

    await this.sendHtml(message, overrideChatId)
  }
}
