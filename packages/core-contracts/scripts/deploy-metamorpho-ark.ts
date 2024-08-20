import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import MetaMorphoArkModule, { MetaMorphoArkContracts } from '../ignition/modules/metamorpho-ark'
import { getConfigByNetwork } from './config-handler'
import { BaseConfig } from './config-types'
import { ModuleLogger } from './module-logger'

/**
 * Main function to deploy a MetaMorphoArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the MetaMorphoArk contract
 * - Logging deployment results
 */
export async function deployMetaMorphoArk() {
    const config = getConfigByNetwork(hre.network.name)

    console.log(kleur.green().bold('Starting MetaMorphoArk deployment process...'))

    const userInput = await getUserInput()

    if (await confirmDeployment(userInput)) {
        console.log(kleur.green().bold('Proceeding with deployment...'))

        const deployedMetaMorphoArk = await deployMetaMorphoArkContract(config, userInput)

        console.log(kleur.green().bold('Deployment completed successfully!'))

        // Logging
        ModuleLogger.logMetaMorphoArk(deployedMetaMorphoArk)
    } else {
        console.log(kleur.red().bold('Deployment cancelled by user.'))
    }
}

/**
 * Prompts the user for MetaMorphoArk deployment parameters.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
 */
async function getUserInput() {
    return await prompts([
        {
            type: 'text',
            name: 'token',
            message: 'Enter the token address:',
        },
        {
            type: 'text',
            name: 'strategyVault',
            message: 'Enter the strategy vault address:',
        },
        {
            type: 'number',
            name: 'maxAllocation',
            message: 'Enter the max allocation:',
        },
    ])
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: any) {
    console.log(kleur.cyan().bold('\nSummary of collected values:'))
    console.log(kleur.yellow(`Token: ${userInput.token}`))
    console.log(kleur.yellow(`Max Allocation: ${userInput.maxAllocation}`))

    const { confirmed } = await prompts({
        type: 'confirm',
        name: 'confirmed',
        message: 'Do you want to continue with the deployment?',
    })

    return confirmed
}

/**
 * Deploys the MetaMorphoArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<MetaMorphoArkContracts>} The deployed MetaMorphoArk contract.
 */
async function deployMetaMorphoArkContract(
    config: BaseConfig,
    userInput: any,
): Promise<MetaMorphoArkContracts> {
    return (await hre.ignition.deploy(MetaMorphoArkModule, {
        parameters: {
            MetaMorphoArkModule: {
                strategyVault: userInput.strategyVault,
                arkParams: {
                    name: 'MetaMorphoArk',
                    accessManager: config.core.protocolAccessManager,
                    configurationManager: config.core.configurationManager,
                    token: userInput.token,
                    maxAllocation: userInput.maxAllocation,
                },
            },
        },
    })) as MetaMorphoArkContracts
}

// Execute the deployMetaMorphoArk function and handle any errors
deployMetaMorphoArk().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
})