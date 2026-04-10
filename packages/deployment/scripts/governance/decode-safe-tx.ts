import fs from 'fs'
import path from 'path'
import { keccak256, toBytes, getAddress, decodeFunctionData, parseAbi } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { getConfigByNetwork } from '../helpers/config-handler'
import kleur from 'kleur'
import hre from 'hardhat'

// Mapping of role hashes to human-readable names
const ROLE_NAMES: Record<string, string> = {
  '0x0000000000000000000000000000000000000000000000000000000000000000': 'DEFAULT_ADMIN_ROLE',
  [keccak256(toBytes('PROPOSER_ROLE'))]: 'PROPOSER_ROLE',
  [keccak256(toBytes('EXECUTOR_ROLE'))]: 'EXECUTOR_ROLE',
  [keccak256(toBytes('CANCELLER_ROLE'))]: 'CANCELLER_ROLE',
  [keccak256(toBytes('GOVERNOR_ROLE'))]: 'GOVERNOR_ROLE',
  [keccak256(toBytes('DECAY_CONTROLLER_ROLE'))]: 'DECAY_CONTROLLER_ROLE',
  [keccak256(toBytes('GUARDIAN_ROLE'))]: 'GUARDIAN_ROLE',
  [keccak256(toBytes('SUPER_KEEPER_ROLE'))]: 'SUPER_KEEPER_ROLE',
  [keccak256(toBytes('ADMIRALS_QUARTERS_ROLE'))]: 'ADMIRALS_QUARTERS_ROLE',
  [keccak256(toBytes('FOUNDATION_ROLE'))]: 'FOUNDATION_ROLE',
}

const HARDCODED_TAGS: Record<string, string> = {
  [getAddress('0x9999Cb59242e8cE485F52eBF82654F3664D63E4f')]: 'OG foundation deployer',
}

function getAddressBook(config: any): Record<string, string> {
  const addressBook: Record<string, string> = { ...HARDCODED_TAGS }

  function scan(obj: any, prefix: string = '') {
    if (!obj || typeof obj !== 'object') return
    for (const key in obj) {
      const val = obj[key]
      if (typeof val === 'string' && val.startsWith('0x') && val.length === 42) {
        try {
          const addr = getAddress(val)
          if (!addressBook[addr]) {
            addressBook[addr] = prefix ? `${prefix}.${key}` : key
          }
        } catch (e) {
          // Ignore invalid addresses
        }
      } else if (typeof val === 'object' && val !== null) {
        scan(val, prefix ? `${prefix}.${key}` : key)
      }
    }
  }

  scan(config)
  return addressBook
}

// ABI for the relevant functions
const GOV_ABI = parseAbi([
  'function grantRole(bytes32 role, address account) external',
  'function revokeRole(bytes32 role, address account) external',
  'function grantGovernorRole(address account) external',
  'function revokeGovernorRole(address account) external',
  'function grantSuperKeeperRole(address account) external',
  'function revokeSuperKeeperRole(address account) external',
  'function grantGuardianRole(address account) external',
  'function revokeGuardianRole(address account) external',
  'function grantDecayControllerRole(address account) external',
  'function revokeDecayControllerRole(address account) external',
  'function grantFoundationRole(address account) external',
  'function revokeFoundationRole(address account) external',
  'function setGuardianExpiration(address account, uint256 expiration) external',
])

async function main() {
  // Find the index of our script in the arguments
  const scriptIndex = process.argv.findIndex((arg) => arg.endsWith('decode-safe-tx.ts'))
  // Only look at arguments AFTER the script name
  const scriptArgs = scriptIndex !== -1 ? process.argv.slice(scriptIndex + 1) : []

  // Try to find a JSON file in positional args
  const filePathArg = scriptArgs.find((arg) => !arg.startsWith('-') && arg.endsWith('.json'))

  // Default to the file matching the current hardhat network's chainId
  const currentChainId = hre.network.config.chainId?.toString()
  const defaultFileName = currentChainId ? `${currentChainId}.json` : '42161.json'
  const filePath = filePathArg || path.join(__dirname, '.test-data', defaultFileName)

  if (!fs.existsSync(filePath)) {
    console.error(kleur.red(`File not found: ${filePath}`))
    process.exit(1)
  }

  const fileContent = fs.readFileSync(filePath, 'utf8')
  const safeTx = JSON.parse(fileContent)
  const chainId = safeTx.chainId

  // Find network name by chainId
  const networks: Record<string, string> = {
    '1': 'mainnet',
    '8453': 'base',
    '42161': 'arbitrum',
    '146': 'sonic',
    '98865': 'hyperliquid',
    '5000': 'mantle',
  }

  const networkName = networks[chainId]
  if (!networkName) {
    console.error(kleur.red(`Unsupported chainId: ${chainId}`))
    process.exit(1)
  }

  console.log(kleur.blue().bold(`Decoding Safe Transactions:`))
  console.log(kleur.blue(`  Network: `), kleur.cyan(networkName), kleur.gray(`(${chainId})`))
  console.log(kleur.blue(`  Source:  `), kleur.gray(filePath))
  console.log('')

  const config = getConfigByNetwork(networkName, {
    common: false,
    gov: true,
    core: false,
  }) as BaseConfig
  const addressBook = getAddressBook(config)

  const timelockAddress = getAddress(config.deployedContracts.govV2.timelock.address)
  const accessManagerAddress = getAddress(
    config.deployedContracts.govV2.protocolAccessManager.address,
  )

  safeTx.transactions.forEach((tx: any, index: number) => {
    const to = getAddress(tx.to)
    let contractName = 'Unknown Contract'
    if (to === timelockAddress) contractName = 'SummerTimelockController / Timelock'
    if (to === accessManagerAddress) contractName = 'ProtocolAccessManager'

    console.log(kleur.white().bold(`Transaction #${index + 1}:`))
    console.log(kleur.blue(`  Contract:`), kleur.cyan(contractName), kleur.gray(`(${to})`))

    // Handle data or contractInputsValues
    let functionName = tx.contractMethod?.name
    let args = tx.contractInputsValues

    if (!functionName && tx.data) {
      try {
        const decoded = decodeFunctionData({
          abi: GOV_ABI,
          data: tx.data as `0x${string}`,
        })
        functionName = decoded.functionName
        args = decoded.args
      } catch (e) {
        // Fallback or ignore
      }
    }

    if (functionName) {
      console.log(kleur.blue(`  Function:`), kleur.yellow(functionName))

      // Extract role and account
      let role = args?.role
      let account = args?.account || (Array.isArray(args) ? args[0] : undefined)

      // Fallback for address args if array
      if (Array.isArray(args)) {
        if (functionName === 'grantRole' || functionName === 'revokeRole') {
          role = args[0]
          account = args[1]
        } else {
          account = args[0]
        }
      }

      // Specific role handling based on function name
      if (functionName.includes('GovernorRole')) role = keccak256(toBytes('GOVERNOR_ROLE'))
      if (functionName.includes('SuperKeeperRole')) role = keccak256(toBytes('SUPER_KEEPER_ROLE'))
      if (functionName.includes('GuardianRole')) role = keccak256(toBytes('GUARDIAN_ROLE'))
      if (functionName.includes('DecayControllerRole'))
        role = keccak256(toBytes('DECAY_CONTROLLER_ROLE'))
      if (functionName.includes('FoundationRole')) role = keccak256(toBytes('FOUNDATION_ROLE'))
      if (functionName.includes('AdmiralsQuartersRole'))
        role = keccak256(toBytes('ADMIRALS_QUARTERS_ROLE'))

      const roleName = ROLE_NAMES[role] || role || 'Unknown Role'
      const readableAction = functionName.includes('revoke')
        ? kleur.red('Revoking')
        : kleur.green('Granting')

      const accountAddr = getAddress(account)
      const accountTag = addressBook[accountAddr]
      const accountDisplay = accountTag
        ? `${kleur.cyan(accountAddr)} [${kleur.green(accountTag)}]`
        : kleur.cyan(accountAddr)

      console.log(
        kleur.white(
          `  Summary:  ${readableAction} ${kleur.magenta(roleName)} for ${accountDisplay}`,
        ),
      )
    } else {
      console.log(kleur.gray(`  Details:  Could not decode function name and arguments.`))
    }
    console.log(kleur.gray('  ' + '-'.repeat(50)))
  })
}

main().catch((err) => {
  console.error(kleur.red().bold('Error:'), err.message)
  process.exit(1)
})
