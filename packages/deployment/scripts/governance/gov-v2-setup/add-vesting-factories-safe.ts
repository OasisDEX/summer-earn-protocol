import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, parseAbi } from 'viem'
import { BaseConfig } from '../../../types/config-types'
import { getConfigByNetwork } from '../../helpers/config-handler'
import { validateAddress } from '../../helpers/validation'

/**
 * @dev Creates a Safe transaction proposal to add vesting factories to SummerVestingWalletsEscrow
 *
 * Vesting factories to add:
 * - 0x5f3cd3a45E6B8c2B29DDC80411C58291740E8886
 * - 0x3aA85a023C0e935CDb5d1CBB2d7BC5EAC5c69BeB (from config: govV2.summerVestingFactoryV2)
 */
export async function addVestingFactoriesSafe(useBummerConfig = false) {
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

  const escrowAddress = validateAddress(
    config.deployedContracts.govV2.summerVestingWalletsEscrow.address,
    'govV2.summerVestingWalletsEscrow',
  )

  const escrow = await hre.viem.getContractAt('SummerVestingWalletsEscrow', escrowAddress)

  const transactions = []

  // Vesting factories to add
  const vestingFactories = [
    config.deployedContracts.gov.summerVestingFactory?.address,
    config.deployedContracts.gov.summerVestingFactoryV2?.address,
  ]

  const addVestingFactoryAbi = parseAbi([
    'function addVestingFactory(address vestingFactory) external',
  ])

  for (const factoryAddress of vestingFactories) {
    const validatedFactory = validateAddress(factoryAddress, 'vestingFactory')

    // Check if factory is already added
    const factories = await escrow.read.vestingFactories()
    const isAlreadyAdded = factories.includes(validatedFactory)

    if (isAlreadyAdded) {
      console.log(kleur.yellow(`⚠️  Factory ${validatedFactory} is already added, skipping...`))
      continue
    }

    transactions.push({
      to: escrowAddress,
      value: '0',
      data: encodeFunctionData({
        abi: addVestingFactoryAbi,
        functionName: 'addVestingFactory',
        args: [validatedFactory],
      }),
      contractMethod: {
        inputs: [{ name: 'vestingFactory', type: 'address' }],
        name: 'addVestingFactory',
        payable: false,
      },
      contractInputsValues: {
        vestingFactory: validatedFactory,
      },
    })
  }

  if (transactions.length === 0) {
    console.log(kleur.green('All vesting factories are already added.'))
    return
  }

  // Create Safe transaction JSON
  const chainId = (await publicClient.getChainId()).toString()
  const timestamp = Date.now()

  const safeTransactionsJson = {
    version: '1.0',
    chainId: chainId,
    createdAt: timestamp,
    meta: {
      name: 'Add Vesting Factories to Escrow',
      description: `Add ${transactions.length} vesting factory(ies) to SummerVestingWalletsEscrow`,
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

  const fileName = `add_vesting_factories_safe_tx_${timestamp}.json`
  const outputPath = path.join(proposalsDir, 'gov-v2-setup', fileName)

  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))

  console.log(kleur.green(`✅ Saved Safe transaction proposal to ${outputPath}`))
  console.log(kleur.yellow('Please execute this transaction via the Safe Transaction Builder.'))
}

if (require.main === module) {
  addVestingFactoriesSafe().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
