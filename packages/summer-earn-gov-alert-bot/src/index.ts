import * as dotenv from 'dotenv'
import cron from 'node-cron'
import { loadState, saveState } from './state'
import { Poller } from './poller'
import { TelegramNotifier } from './telegram'

dotenv.config({ path: "../../.env" })

const TG_BOT_TOKEN = process.env.TG_BOT_TOKEN
const TG_CHAT_ID = process.env.TG_CHAT_ID

if (!TG_BOT_TOKEN || !TG_CHAT_ID) {
  console.error('Missing TG_BOT_TOKEN or TG_CHAT_ID in environment.')
  process.exit(1)
}

const notifier = new TelegramNotifier(TG_BOT_TOKEN, TG_CHAT_ID)

// Manual Poll Command
notifier.bot.command('check', async (ctx) => {
  const targetChatId = ctx.chat.id
  await ctx.reply('🔍 Starting manual polling cycle (dry run)... Result will be sent to YOU.')
  try {
    const state = loadState()
    const poller = new Poller(notifier, state)
    await poller.poll(targetChatId)
    await ctx.reply('✅ Manual polling cycle finished.')
  } catch (error) {
    await ctx.reply(`❌ Error during manual poll: ${error}`)
  }
})

// Single Transaction Diagnostic Command
notifier.bot.command('tx', async (ctx) => {
  const targetChatId = ctx.chat.id
  const args = ctx.message.text.split(' ')
  if (args.length < 3) {
    return ctx.reply('Usage: /tx <network> <hash>')
  }

  const network = args[1].toLowerCase() as any
  const hash = args[2] as `0x${string}`

  await ctx.reply(`🧪 Decoding transaction ${hash} on ${network}... Result will be sent to YOU.`)
  const poller = new Poller(notifier, loadState())
  const success = await poller.processSingleTransaction(network, hash, targetChatId)

  if (success) {
    await ctx.reply('✅ Transaction processed.')
  } else {
    await ctx.reply('❌ Failed to process transaction. Check logs for details.')
  }
})

async function run() {
  console.log('--- Starting Polling Cycle ---')
  const state = loadState()
  const poller = new Poller(notifier, state)

  await poller.poll()

  saveState(poller.getState())
  console.log('--- Polling Cycle Finished ---')
}

// Initial run
run()

// Schedule every 30 minutes
cron.schedule('*/30 * * * *', () => {
  run()
})

// Start Bot Listener
notifier.launch()
  .then(() => console.log('Telegram command listener active.'))
  .catch(err => console.error('Failed to launch Telegram listener:', err))

console.log('Governance Alert Bot is running...')
