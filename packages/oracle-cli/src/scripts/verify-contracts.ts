import fs from 'fs'
import path from 'path'
import { execSync } from 'child_process'
import { encodeAbiParameters, parseAbiParameters, getAddress } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import 'dotenv/config'

const deploymentsPath = path.resolve(__dirname, '../deployments.json')
const deployInputPath = path.resolve(__dirname, '../../deploy-input.json')
const oraclesPackagePath = path.resolve(__dirname, '../../../rwa-oracles')

const SCANNER_API_KEYS: Record<string, string | undefined> = {
  arbitrum: process.env.API_KEY_ETHERSCAN,
  base: process.env.API_KEY_ETHERSCAN,
  mainnet: process.env.API_KEY_ETHERSCAN,
  sonic: process.env.API_KEY_ETHERSCAN,
}

async function main() {
  if (!fs.existsSync(deploymentsPath)) {
    console.error(`Deployments file not found at ${deploymentsPath}`)
    return
  }
  if (!fs.existsSync(deployInputPath)) {
    console.error(`Deploy input file not found at ${deployInputPath}`)
    return
  }

  const privateKey = process.env.DEPLOYER_PRIV_KEY
  if (!privateKey) {
    console.error('DEPLOYER_PRIV_KEY not set in env')
    return
  }
  const account = privateKeyToAccount(privateKey as `0x${string}`)
  console.log(`Deployer address: ${account.address}`)

  const deployments = JSON.parse(fs.readFileSync(deploymentsPath, 'utf-8'))
  const deployInputs = JSON.parse(fs.readFileSync(deployInputPath, 'utf-8'))

  for (const [network, data] of Object.entries(deployments)) {
    const d = data as any
    const apiKey = SCANNER_API_KEYS[network]
    if (!apiKey) {
      console.warn(`No API key found for ${network}, skipping...`)
      continue
    }

    console.log(`\n=== Verifying contracts on ${network} ===`)

    // 1. Verify OracleRegistry
    if (d.oracleRegistry && d.oracleRegistry !== '0x0000000000000000000000000000000000000000') {
      console.log(`Verifying OracleRegistry at ${d.oracleRegistry}...`)
      const constructorArgs = encodeAbiParameters(parseAbiParameters('address'), [account.address])

      try {
        execSync(
          `forge verify-contract ${d.oracleRegistry} src/OracleRegistry.sol:OracleRegistry ` +
            `--chain ${network} --etherscan-api-key ${apiKey} --constructor-args ${constructorArgs} --watch`,
          { cwd: oraclesPackagePath, stdio: 'inherit' },
        )
      } catch (e) {
        console.error(`Failed to verify OracleRegistry on ${network}:`, (e as any).message)
      }
    }

    // 2. Verify RwaOracles
    for (const oracle of d.oracles) {
      console.log(`\nVerifying RwaOracle for ${oracle.ticker} at ${oracle.oracleAddress}...`)

      // Find original input for constructor args
      const input = deployInputs.find(
        (i: any) =>
          i.network === network && getAddress(i.assetAddress) === getAddress(oracle.assetAddress),
      )

      if (!input) {
        console.warn(`Could not find deploy-input for ${oracle.ticker} on ${network}, skipping...`)
        continue
      }

      const constructorArgs = encodeAbiParameters(
        parseAbiParameters('string, address[], uint256, address'),
        [input.description, input.signers, BigInt(input.threshold), account.address],
      )

      try {
        execSync(
          `forge verify-contract ${oracle.oracleAddress} src/RwaOracle.sol:RwaOracle ` +
            `--chain ${network} --etherscan-api-key ${apiKey} --constructor-args ${constructorArgs} --watch`,
          { cwd: oraclesPackagePath, stdio: 'inherit' },
        )
      } catch (e) {
        console.error(
          `Failed to verify RwaOracle for ${oracle.ticker} on ${network}:`,
          (e as any).message,
        )
      }
    }
  }
}

main().catch(console.error)
