import fs from 'fs'
import hre from 'hardhat';
import path from "path";
import FleetModule, { FleetContracts } from '../ignition/modules/fleet';
import { getConfigByNetwork } from './config-handler';
import { BaseConfig } from "./config-types";
import { ModuleLogger } from './module-logger';
import { loadFleetDefinition } from './fleet-definition-handler';
import kleur from 'kleur';
import prompts from 'prompts';

async function deployFleet() {
    const network = hre.network.name;
    const config = getConfigByNetwork(network);

    console.log(kleur.green().bold('Starting Fleet deployment process...'));

    const fleetDefinition = await getFleetDefinition();
    console.log(kleur.blue('Fleet Definition:'));
    console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)));

    const coreContracts: BaseConfig['core'] = config['core'];
    const asset = getAssetAddress(fleetDefinition.assetSymbol, config);

    const bufferArkParams = await getBufferArkParams(coreContracts, asset);

    if (await confirmDeployment(fleetDefinition, bufferArkParams)) {
        console.log(kleur.green().bold('Proceeding with deployment...'));

        const deployedFleet = await deployFleetContracts(fleetDefinition, coreContracts, asset, bufferArkParams);

        console.log(kleur.green().bold('Deployment completed successfully!'));

        logDeploymentResults(deployedFleet);
    } else {
        console.log(kleur.red().bold('Deployment cancelled by user.'));
    }
}

async function getFleetDefinition() {
    const response = await prompts({
        type: 'text',
        name: 'fleetDefinitionPath',
        message: 'Enter the definition file name (in /scripts/fleets):',
        validate: value => fs.existsSync(path.resolve(__dirname, `fleets/${value}`)) ? true : 'File does not exist'
    });

    const fleetDefinitionPath = path.resolve(__dirname, `fleets/${response.fleetDefinitionPath}`);
    console.log(kleur.green(`Loading fleet definition from: ${fleetDefinitionPath}`));

    return loadFleetDefinition(fleetDefinitionPath);
}

function getAssetAddress(assetSymbol: string, config: any) {
    const assetSymbolLower = assetSymbol.toLowerCase() as keyof typeof config.tokens;
    if (!Object.keys(config.tokens).includes(assetSymbolLower)) {
        throw new Error(`No token address for symbol ${assetSymbol} found in config`);
    }
    return config.tokens[assetSymbolLower];
}

async function getBufferArkParams(coreContracts: BaseConfig['core'], asset: string) {
    return await prompts([
        {
            type: 'text',
            name: 'name',
            message: 'Enter the name for the BufferArk:',
            initial: 'BufferArk'
        },
        {
            type: 'text',
            name: 'depositCap',
            message: 'Enter the deposit cap for the BufferArk:',
            validate: value => parseInt(value) > 0 ? true : 'Deposit cap must be greater than 0'
        },
        {
            type: 'text',
            name: 'maxRebalanceOutflow',
            message: 'Enter the max rebalance outflow for the BufferArk:',
            validate: value => parseInt(value) > 0 ? true : 'Max rebalance outflow must be greater than 0'
        },
        {
            type: 'text',
            name: 'maxRebalanceInflow',
            message: 'Enter the max rebalance inflow for the BufferArk:',
            validate: value => parseInt(value) > 0 ? true : 'Max rebalance inflow must be greater than 0'
        }
    ]);
}

async function confirmDeployment(fleetDefinition: any, bufferArkParams: any) {
    console.log(kleur.cyan().bold('\nSummary of collected values:'));
    console.log(kleur.yellow('Fleet Definition:'));
    console.log(kleur.yellow(JSON.stringify(fleetDefinition, null, 2)));
    console.log(kleur.yellow('Buffer Ark Parameters:'));
    console.log(kleur.yellow(JSON.stringify(bufferArkParams, null, 2)));

    const { confirmed } = await prompts({
        type: 'confirm',
        name: 'confirmed',
        message: 'Do you want to continue with the deployment?',
    });

    return confirmed;
}

async function deployFleetContracts(fleetDefinition: any, coreContracts: BaseConfig['core'], asset: string, bufferArkParams: any) {
    return (await hre.ignition.deploy(FleetModule, {
        parameters: {
            FleetModule: {
                configurationManager: coreContracts.configurationManager,
                protocolAccessManager: coreContracts.protocolAccessManager,
                fleetName: fleetDefinition.fleetName,
                fleetSymbol: fleetDefinition.symbol,
                asset,
                initialArks: fleetDefinition.arks,
                initialMinimumFundsBufferBalance: fleetDefinition.initialMinimumFundsBufferBalance,
                initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
                depositCap: fleetDefinition.depositCap,
                initialTipRate: fleetDefinition.initialTipRate,
                minimumRateDifference: fleetDefinition.minimumRateDifference,
                bufferArkParams: {
                    ...bufferArkParams,
                    accessManager: coreContracts.protocolAccessManager,
                    configurationManager: coreContracts.configurationManager,
                    token: asset,
                }
            },
        },
    })) as FleetContracts;
}

function logDeploymentResults(deployedFleet: FleetContracts) {
    ModuleLogger.logFleet(deployedFleet);

    console.log(kleur.yellow().bold('\nIMPORTANT: Commander roles need to be granted via governance'));
    console.log(kleur.yellow('For each initial Ark, the buffer Ark, and the Fleet Commander, call:'));
    console.log(kleur.cyan(`ark.grantCommanderRole(${deployedFleet.fleetCommander.address})`));

    console.log(kleur.yellow('\nBuffer Ark:'));
    console.log(kleur.cyan(deployedFleet.bufferArk.address));

    console.log(kleur.yellow().bold('\nIMPORTANT: The Fleet Commander needs to be enlisted in the Harbor Command via governance'));
    console.log(kleur.yellow('Call:'));
    console.log(kleur.cyan(`harborCommand.enlistFleetCommander(${deployedFleet.fleetCommander.address})`));

    console.log(kleur.green('Fleet deployment completed successfully!'));
    console.log(kleur.yellow('Fleet Commander Address:'), kleur.cyan(deployedFleet.fleetCommander.address));
}

deployFleet().catch((error) => {
    console.error(kleur.red('Error during fleet deployment:'));
    console.error(error);
    process.exit(1);
});