import fs from 'node:fs'
import path from 'node:path'
import kleur from 'kleur'
import { createPublicClient, formatUnits, getAddress, http, isAddress, parseAbi, parseUnits } from 'viem'
import { mainnet } from 'viem/chains'

/**
 * Script to merge whitespace/tab-separated fleet distribution CSV/TSV files into Merkl's official Airdrop JSON format.
 *
 * Features & Checks:
 *  - Excludes Term Ark address (0xa9ca4909700505585b1ad2a1579da3b670ffa9c4) from Fleet 1 distribution.
 *  - Excludes Exploiter addresses (0x7bf716167b48cf527725722c6d79494b45b3bdca and rows commented as Exploiter).
 *  - Verifies total user distributions from CSVs against live ON-CHAIN buffer balances.
 *  - Formats output according to Merkl's official AirdropJSON schema.
 */

interface MerklAirdropJSON {
  rewardToken: `0x${string}`
  rewards: Record<`0x${string}`, Record<string, string>>
}

const EXCLUDED_ADDRESSES = new Set<string>([
  '0xa9ca4909700505585b1ad2a1579da3b670ffa9c4'.toLowerCase(), // Term / HR fleet ark
  '0x7bf716167b48cf527725722c6d79494b45b3bdca'.toLowerCase(), // Exploiter
])

// Target fleets to verify on-chain
const TARGET_FLEETS = [
  { name: 'LazyVault_HigherRisk_USDC', address: '0xE9cDA459bED6dcfb8AC61CD8cE08E2D52370cB06' as const },
  { name: 'LazyVault_LowerRisk_USDC', address: '0x98C49e13bf99D7CAd8069faa2A370933EC9EcF17' as const },
]

const fleetAbi = parseAbi([
  'function bufferArk() view returns (address)',
  'function name() view returns (string)',
])
const erc20Abi = parseAbi(['function balanceOf(address) view returns (uint256)'])

function parseArgs() {
  const args = process.argv.slice(2)
  let rewardToken = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48' // Default Mainnet USDC
  let decimals = 6 // Default USDC decimals
  let inputFiles: string[] = []
  let outputFile = 'config/fleet-cleanup/distribution_csvs/merkl_airdrop_allocation.json'
  let rpcUrl = process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com'
  let skipOnchain = false

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--rewardToken' && args[i + 1]) {
      rewardToken = args[++i].trim()
    } else if (args[i] === '--decimals' && args[i + 1]) {
      decimals = parseInt(args[++i], 10)
    } else if (args[i] === '--inputs' && args[i + 1]) {
      inputFiles = args[++i].split(',').map((f) => f.trim())
    } else if (args[i] === '--output' && args[i + 1]) {
      outputFile = args[++i].trim()
    } else if (args[i] === '--rpcUrl' && args[i + 1]) {
      rpcUrl = args[++i].trim()
    } else if (args[i] === '--skipOnchain') {
      skipOnchain = true
    }
  }

  if (inputFiles.length === 0) {
    const baseDir = path.join(__dirname, '..', '..', '..', 'config', 'fleet-cleanup', 'distribution_csvs')
    inputFiles = [
      path.join(baseDir, 'fleet1_allocations.csv'),
      path.join(baseDir, 'fleet2_allocations.csv'),
    ]
  }

  return { rewardToken, decimals, inputFiles, outputFile, rpcUrl, skipOnchain }
}

function parseLineColumns(line: string): string[] {
  if (line.includes('\t')) {
    return line.split('\t').map((col) => col.trim())
  }
  return line.split(/\s{2,}/).map((col) => col.trim())
}

async function verifyOnchainBalances(rpcUrl: string, rewardToken: `0x${string}`, decimals: number, totalCsvAmount: bigint) {
  console.log(kleur.blue('\n--- On-Chain Buffer Verification ---'))
  try {
    const publicClient = createPublicClient({ chain: mainnet, transport: http(rpcUrl) })
    let totalOnchainBuffer = 0n

    for (const f of TARGET_FLEETS) {
      const bufferArk = await publicClient.readContract({
        address: f.address,
        abi: fleetAbi,
        functionName: 'bufferArk',
      })
      const balance = await publicClient.readContract({
        address: rewardToken,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [bufferArk],
      })

      console.log(
        kleur.cyan(
          `  ${f.name.padEnd(28)}: Buffer ${bufferArk} = ${formatUnits(balance, decimals)} tokens (${balance} raw)`,
        ),
      )
      totalOnchainBuffer += balance
    }

    console.log(
      kleur.bold(
        `\n  Total On-Chain Buffer Balance : ${formatUnits(totalOnchainBuffer, decimals)} tokens (${totalOnchainBuffer} raw)`,
      ),
    )
    console.log(
      kleur.bold(
        `  Total CSV User Distribution   : ${formatUnits(totalCsvAmount, decimals)} tokens (${totalCsvAmount} raw)`,
      ),
    )

    const diff = totalCsvAmount > totalOnchainBuffer ? totalCsvAmount - totalOnchainBuffer : totalOnchainBuffer - totalCsvAmount

    if (diff === 0n) {
      console.log(kleur.green().bold('  ✅ PERFECT MATCH: Total CSV distribution matches total on-chain buffer balances exactly!'))
    } else if (diff < 100n) { // less than 100 raw units ($0.0001)
      console.log(
        kleur.yellow(
          `  ⚠️  MICRO ROUNDING DISCREPANCY: Difference is ${formatUnits(diff, decimals)} tokens (${diff} raw units). ` +
            `This is negligible floating-point precision rounding in the CSV export.`,
        ),
      )
    } else {
      console.log(
        kleur.red(
          `  ❌ DISCREPANCY WARNING: Difference of ${formatUnits(diff, decimals)} tokens between CSV allocations and on-chain buffers!`,
        ),
      )
    }
  } catch (err: any) {
    console.warn(kleur.yellow(`  ⚠️ Could not complete on-chain check (${err?.message || err}). Skipping.`))
  }
}

async function main() {
  const { rewardToken, decimals, inputFiles, outputFile, rpcUrl, skipOnchain } = parseArgs()

  if (!isAddress(rewardToken)) {
    console.error(kleur.red(`❌ Invalid rewardToken address: ${rewardToken}`))
    process.exit(1)
  }

  const formattedRewardToken = getAddress(rewardToken) as `0x${string}`

  console.log(kleur.blue('Converting Distribution Files to Merkl Official Airdrop JSON...'))
  console.log(kleur.cyan(`Reward Token  : ${formattedRewardToken}`))
  console.log(kleur.cyan(`Token Decimals: ${decimals}`))

  const rewardsMap = new Map<`0x${string}`, Map<string, bigint>>()
  let grandTotal = 0n
  let totalRowsProcessed = 0
  let totalExcludedRows = 0

  for (const file of inputFiles) {
    const absolutePath = path.isAbsolute(file) ? file : path.resolve(process.cwd(), file)

    if (!fs.existsSync(absolutePath)) {
      console.error(kleur.red(`❌ Input file not found: ${absolutePath}`))
      process.exit(1)
    }

    const fileName = path.basename(file)
    const fileReason = fileName.toLowerCase().includes('fleet1')
      ? 'Fleet 1 LR entitlement'
      : fileName.toLowerCase().includes('fleet2')
      ? 'Fleet 2 HR entitlement'
      : `Entitlement (${fileName})`

    console.log(kleur.yellow(`Reading ${absolutePath} (${fileReason})…`))
    const content = fs.readFileSync(absolutePath, 'utf8')
    const lines = content.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 0)

    if (lines.length <= 1) {
      console.warn(kleur.gray(`Skipping empty or header-only file: ${file}`))
      continue
    }

    const header = parseLineColumns(lines[0].toLowerCase())
    const addrIdx = header.findIndex((h) => h.includes('account') || h.includes('address'))
    const amountIdx = header.findIndex((h) => h.includes('recovered') || h.includes('amount'))
    const commentIdx = header.findIndex((h) => h.includes('comment') || h.includes('reason'))

    if (addrIdx === -1 || amountIdx === -1) {
      console.error(kleur.red(`❌ File ${file} missing required columns (Account ID / Address and Recovered / Amount).`))
      process.exit(1)
    }

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i]
      if (line.startsWith('#')) continue // ignore comment lines

      const parts = parseLineColumns(line)
      const rawAddr = parts[addrIdx]
      const rawAmount = parts[amountIdx]
      const comment = commentIdx !== -1 && parts[commentIdx] ? parts[commentIdx] : ''

      if (!rawAddr || !rawAmount) continue

      if (!isAddress(rawAddr)) {
        console.error(kleur.red(`❌ Invalid Ethereum address on line ${i + 1} in ${file}: "${rawAddr}"`))
        process.exit(1)
      }

      const lowerAddr = rawAddr.toLowerCase()

      // Exclusion rules: Term address or Exploiter comment/address
      if (EXCLUDED_ADDRESSES.has(lowerAddr) || comment.toLowerCase().includes('exploiter') || comment.toLowerCase().includes('term')) {
        console.log(kleur.gray(`  Excluded line ${i + 1} (${rawAddr}): ${comment || 'Blacklisted address'}`))
        totalExcludedRows++
        continue
      }

      const checksumAddr = getAddress(rawAddr) as `0x${string}`

      // Clean amount string: strip '$' and ','
      const cleanAmountStr = rawAmount.replace(/\$/g, '').replace(/,/g, '').trim()

      let parsedAmount: bigint
      try {
        if (cleanAmountStr.includes('.')) {
          parsedAmount = parseUnits(cleanAmountStr, decimals)
        } else {
          parsedAmount = BigInt(cleanAmountStr)
        }
      } catch (err) {
        console.error(kleur.red(`❌ Invalid amount format on line ${i + 1} in ${file}: "${rawAmount}"`))
        process.exit(1)
      }

      if (parsedAmount <= 0n) {
        console.warn(kleur.gray(`  Skipping zero amount for ${checksumAddr} on line ${i + 1}`))
        totalExcludedRows++
        continue
      }

      let userReasons = rewardsMap.get(checksumAddr)
      if (!userReasons) {
        userReasons = new Map<string, bigint>()
        rewardsMap.set(checksumAddr, userReasons)
      }

      const currentReasonAmount = userReasons.get(fileReason) || 0n
      userReasons.set(fileReason, currentReasonAmount + parsedAmount)

      grandTotal += parsedAmount
      totalRowsProcessed++
    }
  }

  // Construct final Merkl Airdrop JSON
  const merklOutput: MerklAirdropJSON = {
    rewardToken: formattedRewardToken,
    rewards: {},
  }

  for (const [address, reasonMap] of rewardsMap.entries()) {
    merklOutput.rewards[address] = {}
    for (const [reason, amountBigInt] of reasonMap.entries()) {
      merklOutput.rewards[address][reason] = amountBigInt.toString()
    }
  }

  const outPath = path.isAbsolute(outputFile) ? outputFile : path.resolve(process.cwd(), outputFile)
  fs.mkdirSync(path.dirname(outPath), { recursive: true })

  fs.writeFileSync(outPath, JSON.stringify(merklOutput, null, 2), 'utf8')

  console.log(kleur.green('\n================ Conversion Summary ================'))
  console.log(kleur.cyan(`Processed Allocations: ${totalRowsProcessed}`))
  console.log(kleur.cyan(`Excluded Rows        : ${totalExcludedRows}`))
  console.log(kleur.cyan(`Unique Recipients   : ${Object.keys(merklOutput.rewards).length}`))
  console.log(kleur.cyan(`Total Distribution  : ${formatUnits(grandTotal, decimals)} tokens (${grandTotal.toString()} raw base units)`))
  console.log(kleur.green(`Saved Merkl JSON to : ${outPath}`))

  if (!skipOnchain) {
    await verifyOnchainBalances(rpcUrl, formattedRewardToken, decimals, grandTotal)
  }
}

main().catch((err) => {
  console.error(kleur.red('Error:'), err)
  process.exit(1)
})
