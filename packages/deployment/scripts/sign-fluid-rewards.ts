import fs from 'fs'
import path from 'path'
import { createWalletClient, http, type Hex } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet, arbitrum, base } from 'viem/chains'
import dotenv from 'dotenv'

dotenv.config()

// Program IDs by network
const PROGRAM_ID_BY_NETWORK: Record<string, string> = {
  mainnet: 'inst-rewards-dec-2024',
  arbitrum: 'arb-fluid-rewards-jul-2025',
  base: 'base-fluid-rewards-jul-2025',
}

interface Position {
  positionId: string
  deployer: string
  positionType: number
  user: string
  cycle: number
  amount: string
  amountWei: string
  cumulativeAmount: string
  cumulativeAmountWei: string
  metadata: string
  proof: string[]
  message?: string
  signature?: string
}

type NetworkData = Record<string, Position[]>
type FluidRewardsData = Record<string, NetworkData>

const INPUT_FILE = 'fluid_rewards_data.json'
const OUTPUT_FILE = 'fluid_rewards_data_signed.json'

function getPrivateKeyForDeployer(deployer: string): Hex | undefined {
  // Try to find environment variable for specific deployer
  // Expected format: DEPLOYER_KEY_0x123...
  const envKey = `DEPLOYER_KEY_${deployer}`
  const privateKey = process.env[envKey]

  if (privateKey) {
    return privateKey as Hex
  }

  // Also try normalizing address (remove 0x, uppercase, etc if needed)
  // but strict matching is safer first.
  return undefined
}

async function main() {
  const filePath = path.resolve(process.cwd(), INPUT_FILE)
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`)
    process.exit(1)
  }

  const rawData = fs.readFileSync(filePath, 'utf-8')
  const data: FluidRewardsData = JSON.parse(rawData)

  let signCount = 0
  let skipCount = 0
  let errorCount = 0

  for (const [networkName, users] of Object.entries(data)) {
    const programId = PROGRAM_ID_BY_NETWORK[networkName]
    if (!programId) {
      console.warn(`Unknown network: ${networkName}, skipping...`)
      continue
    }

    console.log(`Processing network: ${networkName} (Program ID: ${programId})`)

    for (const [userAddress, positions] of Object.entries(users)) {
      for (const position of positions) {
        const deployer = position.deployer
        const privateKey = getPrivateKeyForDeployer(deployer)

        if (!privateKey) {
          console.warn(
            `  Warning: No private key found for deployer ${deployer} (Env var: DEPLOYER_KEY_${deployer})`,
          )
          skipCount++
          // Add the unsigned message anyway as requested ("signed an unsgined messages added")
          const message = `As the authority for address ${userAddress} we hereby confirm that all FLUID rewards in the Merkle program ${programId} accrued until now, should be claimed through an admin workaround at the MerkleDistributor contract on behalf of us and sent to the address ${userAddress}.`
          position.message = message
          continue
        }

        try {
          const account = privateKeyToAccount(privateKey)
          console.log(account.address)
          // Construct the message
          // "As the authority for address <key_of_entry>  we hereby confirm that all FLUID rewards in the Merkle program <program-id> accrued until now, should be claimed through an admin workaround at the MerkleDistributor contract on behalf of us and sent to the address <recipient>."
          const message = `As the authority for address ${userAddress} we hereby confirm that all FLUID rewards in the Merkle program ${programId} accrued until now, should be claimed through an admin workaround at the MerkleDistributor contract on behalf of us and sent to the address ${userAddress}.`

          const signature = await account.signMessage({
            message: message,
          })

          position.message = message
          position.signature = signature

          console.log(`  Signed message for user ${userAddress}, position ${position.positionId}`)
          signCount++
        } catch (err) {
          console.error(`  Error signing for user ${userAddress}:`, err)
          errorCount++
        }
      }
    }
  }

  const outputPath = path.resolve(process.cwd(), OUTPUT_FILE)
  fs.writeFileSync(outputPath, JSON.stringify(data, null, 2))

  console.log(`\nDone!`)
  console.log(`Signed: ${signCount}`)
  console.log(`Skipped (no key/recipient): ${skipCount}`)
  console.log(`Errors: ${errorCount}`)
  console.log(`Output written to: ${OUTPUT_FILE}`)
}

main().catch(console.error)
