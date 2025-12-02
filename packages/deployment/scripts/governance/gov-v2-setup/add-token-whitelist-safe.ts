import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, parseAbi } from 'viem'
import { BaseConfig } from '../../../types/config-types'
import { getConfigByNetwork } from '../../helpers/config-handler'
import { validateAddress } from '../../helpers/validation'

/**
 * @dev Creates a Safe transaction proposal to add an address to the SummerToken whitelist
 *
 * Address to whitelist:
 * - 0xcA2e14c7C03C9961c296C89e2d2279F5F7DB15b4 (SummerStaking contract from config)
 */
export async function addTokenWhitelistSafe(useBummerConfig = false) {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: true, core: false },
    useBummerConfig,
  ) as BaseConfig

  const publicClient = await hre.viem.getPublicClient()
  const foundationMultisig = process.env.FOUNDATION_MULTISIG_ADDRESS
  if (!foundationMultisig) {
    throw new Error('FOUNDATION_MULTISIG_ADDRESS environment variable is not set')
  }
  const multisigAddress = validateAddress(foundationMultisig, 'FOUNDATION_MULTISIG_ADDRESS')

  const tokenAddress = validateAddress(
    config.deployedContracts.gov.summerToken.address,
    'summerToken',
  )

  // Address to whitelist: SummerStaking contract
  const addressToWhitelist = validateAddress(
    config.deployedContracts.govV2.summerStaking.address,
    'govV2.summerStaking',
  )

  const summerToken = await hre.viem.getContractAt('SummerToken', tokenAddress)

  const transactions = []

  // Check if address is already whitelisted
  const isWhitelisted = await summerToken.read.whitelistedAddresses([addressToWhitelist])

  if (isWhitelisted) {
    console.log(
      kleur.yellow(`⚠️  Address ${addressToWhitelist} is already whitelisted, skipping...`),
    )
    return
  }

  const addToWhitelistAbi = parseAbi(['function addToWhitelist(address account) external'])

  transactions.push({
    to: tokenAddress,
    value: '0',
    data: encodeFunctionData({
      abi: addToWhitelistAbi,
      functionName: 'addToWhitelist',
      args: [addressToWhitelist],
    }),
    contractMethod: {
      inputs: [{ name: 'account', type: 'address' }],
      name: 'addToWhitelist',
      payable: false,
    },
    contractInputsValues: {
      account: addressToWhitelist,
    },
  })

  // Create Safe transaction JSON
  const chainId = (await publicClient.getChainId()).toString()
  const timestamp = Date.now()

  const safeTransactionsJson = {
    version: '1.0',
    chainId: chainId,
    createdAt: timestamp,
    meta: {
      name: 'Add Address to SummerToken Whitelist',
      description: `Add SummerStaking contract (${addressToWhitelist}) to SummerToken whitelist`,
      txBuilderVersion: '1.16.3',
      createdFromSafeAddress: multisigAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions,
  }

  // Ensure proposals directory exists
  const proposalsDir = path.join(process.cwd(), 'proposals')
  if (!fs.existsSync(proposalsDir)) {
    fs.mkdirSync(proposalsDir, { recursive: true })
  }

  const fileName = `add_token_whitelist_safe_tx_${timestamp}.json`
  const outputPath = path.join(proposalsDir, 'gov-v2-setup', fileName)

  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))

  console.log(kleur.green(`✅ Saved Safe transaction proposal to ${outputPath}`))
  console.log(kleur.yellow('Please execute this transaction via the Safe Transaction Builder.'))
}

if (require.main === module) {
  addTokenWhitelistSafe().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
