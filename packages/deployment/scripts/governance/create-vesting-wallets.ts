import dotenv from 'dotenv'
import fs from 'fs'
import path from 'path'
import prompts from 'prompts'
import {
    Address,
} from 'viem'
import { base } from 'viem/chains'
import hre from 'hardhat'
import { getConfigByNetwork } from '../helpers/config-handler'

const VESTING_TYPE = {
    TeamVesting: 0,
    InvestorExTeamVesting: 1,
}

dotenv.config()

// Load configuration from index.json
const config = getConfigByNetwork(hre.network.name)

// Load vesting distribution configuration
const vestingPath = path.resolve(__dirname, '../../config/distributions/vesting.json')
const vestingConfig = JSON.parse(fs.readFileSync(vestingPath, 'utf-8'))

const chainConfig = {
    chain: base,
    config: config,
    rpcUrl: process.env.BASE_RPC_URL as string,
}

async function main() {
    console.log('🚀 Starting vesting wallet creation process...\n')
    console.log('Instantiating SummerToken... ' + chainConfig.config.deployedContracts.gov.summerToken.address)
    const summerToken = await hre.viem.getContractAt('SummerToken' as string, chainConfig.config.deployedContracts.gov.summerToken.address as Address)
    console.log('Instantiating SummerVestingWalletFactory...')
    const FACTORY_ADDRESS = (await summerToken.read.vestingWalletFactory()) as Address

    console.log('FACTORY_ADDRESS', FACTORY_ADDRESS)
    // Show all beneficiaries and ask which one to process
    const beneficiaries = Object.keys(vestingConfig)

    for (const beneficiary of beneficiaries) {
        const vestingData = vestingConfig[beneficiary]
        const timeBasedAmount = BigInt(vestingData.timeBased)
        const goalAmounts = vestingData.goals ? vestingData.goals.map(BigInt) : []

        // Ask for vesting type
        const vestingType = vestingData.goals ? VESTING_TYPE.TeamVesting : VESTING_TYPE.InvestorExTeamVesting

        // Show final confirmation with all details
        const { confirmed } = await prompts({
            type: 'confirm',
            name: 'confirmed',
            message:
                `📝 Please review the operation details:\n\n` +
                `Chain: Base\n` +
                `Beneficiary: ${beneficiary}\n` +
                `Time-based Amount: ${timeBasedAmount}\n` +
                `Goal Amounts: ${goalAmounts.join(', ')}\n` +
                `Vesting Type: ${vestingType === 0 ? 'Linear' : 'Cliff'}\n` +
                `Factory: ${FACTORY_ADDRESS}\n\n` +
                `Would you like to proceed with creating the vesting wallet?`,
            initial: false,
        })

        if (!confirmed) {
            throw new Error('Operation cancelled by user')
        }

        console.log('📋 Creating vesting wallet...')
        const vestingWalletFactory = await hre.viem.getContractAt('SummerVestingWalletFactory' as string, FACTORY_ADDRESS)
        const tx = await vestingWalletFactory.write.createVestingWallet([
            beneficiary as Address,
            timeBasedAmount,
            goalAmounts,
            vestingType,
        ])

        console.log(`Transaction sent: ${tx}`)

        console.log('✅ Vesting wallet created successfully!')
    }


}

main().catch((error) => {
    console.error('❌ Error:', error)
    process.exit(1)
})